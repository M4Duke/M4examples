TCP Echo server for PC & CPC and Client for CPC for testing M4 board
====================================================================


Run tcpserv.exe on your PC and run tcpc.bin on your CPC.

Or run"tcpserv.bin" on CPC and do a telnet ip num 4660 (port) from pc 

Or run"tcpserv.bin" on one CPC and run"tcpc.bin" on another CPC

Type the PC server IP when prompted, format like 192.168.1.10, afterwards you can send messages to the PC that will be echo'ed back.
This is purely for testing, no practical use!

Now updated for M4 firmware v1.0.9b7 with HOST net API.

tcp.s       - tcp client z80 code for maxam.


tcpc.bin    - binary of client, run"tcpc"


tcpserv.s   - tcp server z80 code for maxam.


tcpserv.bin - binary for server, run"tcpserv"

main.c, makefile - tcp echo server for windows/linux  (remove wsock32 in makefile for linux build)


tcpserv.exe - windows build for tcp echo server.


Other examples
==============

lookup.s    - Example use of dns lookup.

httpget.s   - Raw http get example, using netapi. Will download and display m4info.txt

sd_readsector.s - Reads a sector from the SD card and displays its contents

romup.s     - Example to use direct fat file i/o and upload new rom to M4 "romboard"

telnet.s    - Super simple telnet client example, only does a few basics, needs more work.

telnet.bin  - Binary version, download to cpc and run"telnet

m4reconf.s - Re-programs M4 flash with contents of romslots.bin&romconfig.bin, ie. use other peoples romsetup.

m4reconf.bin - Binary version, run from /M4 directory

savelow.s  - Simply program demonstrating the new feature of FW2.0.7 to change between lowerroms.

savelow.bin  - Binary version. Will dump all 3 lowerroms of M4 board to microSD.

getdir.s      - Example to use native M4 board commands to retrive a directory.

fastcopy.s    - Example to copy files via amsdos cas_in/cas_out but using its buffer & ptrs for fast(er) speed.

-Duke
