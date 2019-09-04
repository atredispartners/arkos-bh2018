all: disk.img prom.ihex


disk.img: files/* make_disk.py
	python make_disk.py disk.img

prom.ihex: prom.bin
	../bin/ftohex 2 prom.bin prom.ihex

prom.bin: prom.asm
	../bin/dasm prom.asm  -v4 -f2 -oprom.bin -Lprom.lst -sprom.map

