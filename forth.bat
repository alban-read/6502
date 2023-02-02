@echo off
64tass -q -b -Wall -C -c forth.asm -L forth.lst -o forth.bin
python fnxmgr.zip --port COM3 --binary forth.bin --address 2000
