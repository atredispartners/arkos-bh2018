import sys
import os
import struct
import logging

CLOUDWATCH_DELAY = os.environ.get('ARKOS_CLOUDWATCH_DELAY')

logger = logging.getLogger(__name__)
if CLOUDWATCH_DELAY is not None:
    import watchtower
    logger.addHandler(watchtower.CloudWatchLogHandler(send_interval=int(CLOUDWATCH_DELAY)))

from py65.devices.mpu6502 import MPU as NMOS6502
from py65.memory import ObservableMemory

import os
import termios
import fcntl

class Info(object):
    INFO_BASE_ADDRESS = 0xF400

    def __init__(self, bot):
        self.bot = bot # maybe weak?
        self.info = b'1.0.3 rev A'
        self.reset()

    def reset(self):
        self.bot.mpu.memory.subscribe_to_read(list(range(Info.INFO_BASE_ADDRESS, Info.INFO_BASE_ADDRESS + 0x40)), self.read)

    def read(self, address):
        offset = address - Info.INFO_BASE_ADDRESS
        if offset >= len(self.info):
            return 0
        else:
            return self.info[offset]

class Console(object):
    # getc
    GETC_ADDRESS = 0xF000
    PUTC_ADDRESS = 0xF001

    def __init__(self, bot, s):
        self.bot = bot # maybe weak?
        self.s = s
        self.s.settimeout(60.0)
        self.reset()

    def reset(self):
        self.bot.mpu.memory.subscribe_to_write([Console.PUTC_ADDRESS], self.putc)
        self.bot.mpu.memory.subscribe_to_read([Console.GETC_ADDRESS], self.getc)
        self.buffer = b''

    def putc(self, address, value):
        try:
            self.s.sendall(bytes([value]))
        except:
            self.bot.status = 'halted'

        self.bot.cycles_since_io = 0
        #sys.stdout.write(chr(value))
        #sys.stdout.flush()

    def getc(self, address):
        #return ord(sys.stdin.read(1))
        try:
            data = self.s.recv(1)
            if not data:
                self.bot.status = 'halted'
            else:
                if (ord(data) in [0x0a, 0x0d] and self.buffer) or len(self.buffer) >= 80:
                    logger.info({'host': self.bot.host,
                                 'details': self.buffer.decode('ascii', 'ignore')})
                    self.buffer = b''
                elif ord(data) not in [0x0a, 0x0d]:
                    self.buffer += data
                return ord(data)
        except Exception as e:
            self.bot.status = 'halted'

        self.bot.cycles_since_io = 0


class Disk(object):
    STATUS_REGISTER = 0xF200
    COMMAND_REGISTER = 0xF201
    DATA_LOW_REGISTER = 0xF202
    DATA_HIGH_REGISTER = 0xF203
    ADDRESS_LOW_REGISTER = 0xF210
    ADDRESS_HIGH_REGISTER = 0xF211
    BUFFER_LOW_REGISTER = 0xF220
    BUFFER_HIGH_REGISTER = 0xF221

    STATUS_READ_ONLY = 0b0001
    STATUS_IDLE = 0b0010

    def __init__(self, bot, image):
        self.bot = bot
        self.image = image
        self.reset()

    def reset(self):
        self.bot.mpu.memory.subscribe_to_write([Disk.COMMAND_REGISTER], self.write_command)
        #self.bot.mpu.memory.subscribe_to_read([Disk.STATUS_REGISTER], self.read_status)
        self.bot.mpu.memory.subscribe_to_read([Disk.DATA_LOW_REGISTER], self.read_data)
        self.bot.mpu.memory.subscribe_to_read([Disk.DATA_HIGH_REGISTER], self.read_data)
        self.bot.mpu.memory.subscribe_to_write([Disk.ADDRESS_LOW_REGISTER], self.write_address)
        self.bot.mpu.memory.subscribe_to_write([Disk.ADDRESS_HIGH_REGISTER], self.write_address)
        self.bot.mpu.memory.subscribe_to_write([Disk.BUFFER_LOW_REGISTER], self.write_buffer)
        self.bot.mpu.memory.subscribe_to_write([Disk.BUFFER_HIGH_REGISTER], self.write_buffer)

        self.reg_status = 0
        self.reg_command = 0
        self.reg_data = 0
        self.reg_address = 0
        self.reg_buffer = 0

    def read_data(self, address):
        if address == Disk.DATA_LOW_REGISTER:
            return self.reg_data & 0xff
        elif address == Disk.DATA_HIGH_REGISTER:
            return (self.reg_data >> 8) & 0xff

    def write_address(self, address, value):
        if address == Disk.ADDRESS_LOW_REGISTER:
            self.reg_address = (self.reg_address & 0xff00) | (value & 0xff)
        elif address == Disk.ADDRESS_HIGH_REGISTER:
            self.reg_address = (self.reg_address & 0x00ff) | ((value << 8) & 0xff00)

    def write_buffer(self, address, value):
        if address == Disk.BUFFER_LOW_REGISTER:
            self.reg_buffer = (self.reg_buffer & 0xff00) | (value & 0xff)
        elif address == Disk.BUFFER_HIGH_REGISTER:
            self.reg_buffer = (self.reg_buffer & 0x00ff) | ((value << 8) & 0xff00)

    def command_read_sector(self):
        #print('*** ${:04x}'.format(self.reg_address))
        # Move 0x40 bytes from disk @ REG_ADDRESS to memory @ REG_BUFFER
        offset = self.reg_address * 0x40  # Address is in sectors
        self.image.seek(offset)
        sector_data = self.image.read(0x40)
        self.bot.mpu.memory[self.reg_buffer:self.reg_buffer + 0x40] = sector_data

    def write_command(self, address, value):
        # Read sector (64 bytes)
        if value == 0x81:
            self.command_read_sector()


class Power(object):
    STATUS_REGISTER = 0xF100
    CONTROL_REGISTER = 0xF101

    def __init__(self, bot):
        self.bot = bot # maybe weak?
        self.reset()

    def reset(self):
        self.bot.mpu.memory.subscribe_to_write([Power.CONTROL_REGISTER], self.write_control)
        self.bot.mpu.memory.subscribe_to_read([Power.STATUS_REGISTER], self.read_status)
        self.status = 0xA1

    def read_status(self, address):
        return self.status

    def write_control(self, address, value):
        if value == 0xA5:
            # Reset
            pass


class Bot(object):
    def __init__(self, console_fo, disk_fo):
        self.mpu = NMOS6502(memory=ObservableMemory())
        self.hw = {}
        self.hw['console'] = Console(self, console_fo)
        self.hw['info'] = Info(self)
        self.hw['pmc'] = Power(self)
        self.hw['disk'] = Disk(self, disk_fo)
        self._status = 'halted'

    def reset(self):
        self.mpu = NMOS6502(memory=ObservableMemory())
        for name, module in self.hw.items():
            module.reset()
        self.status = 'halted'

    @property
    def status(self):
        return self._status

    @status.setter
    def status(self, new_status):
        self._status = new_status

    def write_byte(self, address, value):
        self.mpu.memory[address] = value

    def read_word(self, address):
        return struct.unpack('<H', bytes(self.mpu.memory[address:address+2]))[0]

    def execute(self, timeout=None, pc=None, cycles=None):
        if pc is not None:
            self.mpu.pc = pc

        if timeout is None:
            deadline = None
        else:
            deadline = time.time() + timeout

        assert self.status in ['queued']

        self.cycles_since_io = 0
        done = False
        self.status = 'running'
        while not done:
            #print('{!r}'.format(self.mpu))
            self.mpu.step()
            self.cycles_since_io += 1

            if self.status != 'running':
                break

            if deadline is not None and time.time() >= deadline:
                # Put it back on the queue
                self.status = 'queued'
                break

            if cycles is not None and self.cycles_since_io >= cycles:
                logger.info({'host': self.host,
                             'details': 'Too many cycles without IO'})
                self.status = 'queued'
                break

        return self.status

