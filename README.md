# The Atredis ArkOS Blackhat 2018 Ticket Challenge

## Setting it up and running it

1. Create a python3 venv:

    ```bash
    $ python3 -m venv arkos
    ...
    $ . ./arkos/bin/activate
    ...
    (arkos)$ pip install -r requirements.txt
    ...```

2. Run the server:

    ```bash
    (arkos)$ python3 ./server.py 4444 release1/prom.ihex release1/disk.img
    ```

3. From another shell, launch a client to check your work:

    ```bash
    $ nc localhost 4444
    Starting ArkOS...
    Hardware version: 1.0.3 rev A
    Firmware version: 1.1.B
    Memory map:
      $0000:$00FF - RAM
      $0100:$01FF - RAM (stack)
      $0200:$1FFF - RAM
      $4000:$EFFF - PROM
      $F000:$FF00 - MMIO
      $FF00:$FFFF - PROM
    Found /etc/motd!
    ...
    ```

    The server should log the connection:

    ```
    INFO:__main__:{'host': '127.0.0.1', 'details': 'Connect'}
    ```

## Building the PROM binary and disk image from source

1. Clone and build DASM from https://github.com/munsie/dasm
2. Create a `bin/` in the repository and copy the `dasm` and `ftohex` binaries there
3. `cd release1` and `make` to generate fresh `prom.ihex` and `disk.img`


