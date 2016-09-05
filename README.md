TCP Echo server for PC & CPC and Client for CPC for testing M4 board

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


lookup.s    - Example use of dns lookup.


main.c, makefile - tcp echo server for windows/linux  (remove wsock32 in makefile for linux build)


tcpserv.exe - windows build for tcp echo server.



-Duke
