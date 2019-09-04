import os
import socket
import sys
import socketserver
import logging

from intelhex import IntelHex

from hw import Bot

SENTRY_URL = os.environ.get('ARKOS_SENTRY_URL')
CLOUDWATCH_DELAY = os.environ.get('ARKOS_CLOUDWATCH_DELAY')

class TCPRequestHandler(socketserver.BaseRequestHandler):
    def handle(self):
        logger = logging.getLogger(__name__)
        logger.info({'host': self.client_address[0],
                     'details': 'Connect'})

        if SENTRY_URL is not None:
            from raven import Client
            client = Client(SENTRY_URL)
            client.captureMessage('Connect', tags={'remote_host': self.client_address[0], 'level': 'info'})
        else:
            client = None

        try:
            disk = open(self.server.disk_image_path, 'r+b')
            bot = Bot(self.request, disk)
            bot.host = self.client_address[0]
            bot.reset()

            load_ihex(bot, self.server.prom_ihex_path)
            bot.status = 'queued'
            pc = bot.read_word(0xfffa)
            bot.execute(pc=pc, cycles=10000)
        except Exception as e:
            if client is not None:
                client.captureException(tags={'remote_host': self.client_address[0]})
        finally:
            logger.info({'host': self.client_address[0],
                         'details': 'Disconnect'})
            if client is not None:
                client.captureMessage('Disconnect', tags={'remote_host': self.client_address[0], 'level': 'info'})

class ForkedTCPServer(socketserver.ForkingMixIn, socketserver.TCPServer):
    allow_reuse_address = True

def load_ihex(bot, ihex_path):
    ih = IntelHex(ihex_path)
    for chunk in ih.segments():
        for addr in range(*chunk):
            bot.write_byte(addr, ih[addr])

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    if CLOUDWATCH_DELAY is not None:
        import watchtower
        logging.getLogger(__name__).addHandler(watchtower.CloudWatchLogHandler(send_interval=int(CLOUDWATCH_DELAY)))

    HOST = '0.0.0.0'
    PORT = int(sys.argv[1])
    prom_ihex_path = sys.argv[2]
    disk_image_path = sys.argv[3]

    with ForkedTCPServer((HOST, PORT), TCPRequestHandler) as server:
        server.prom_ihex_path = prom_ihex_path
        server.disk_image_path = disk_image_path
        server.serve_forever()

