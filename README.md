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

2. Run the server

    ```bash
    (arkos)$ python3 ./server.py 4444 release1/prom.ihex release1/disk.img
    ```

3. Launch a client to check your work

    ```bash
    $ nc localhost 4444
    ```

## Building the PROM binary and disk image from source

1. Clone and build DASM from https://github.com/munsie/dasm
2. Create a `bin/` in the repository and copy the `dasm` and `ftohex` binaries there
3. `cd release1` and `make` to generate fresh `prom.ihex` and `disk.img`


