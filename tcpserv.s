
			; TCP Echo Server example for M4 Board
			; Requires firmware v1.0.9b7 upwards
			; Duke 2016
			
			org	&9000
			nolist
DATAPORT		equ &FE00
ACKPORT		equ &FC00			

C_NETSTAT		equ &4323
C_TIME		equ &4324
C_VERSION		equ &4326
C_NETSOCKET	equ &4331
C_NETCONNECT	equ &4332
C_NETCLOSE	equ &4333
C_NETSEND		equ &4334
C_NETRECV		equ &4335
C_NETHOSTIP	equ &4336
C_NETRSSI		equ &4337
C_NETBIND		equ &4338
C_NETLISTEN	equ &4339
C_NETACCEPT	equ &433A

start:		

			push	iy
			push	ix
			ld	a,(m4_rom_num)
			cp	&FF
			call	z,find_m4_rom	; find rom (only first run)
							; should add version check too and make sure its v1.0.9
			cp	&FF
			call	nz,tcpserver
			
			pop	ix
			pop	iy
			ret
	
tcpserver:	ld	a,2			
			call	&bc0e		; set mode 2

			ld	hl,&FF02	; get response buffer address
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			push	de
			pop	iy
			ld	hl,msgserver
			call	disptextz
		
			; get connection status 
			
			ld	hl,cmdnetstat
			call	sendcmd
			push	iy
			pop	hl
			inc	hl
			inc	hl
			inc	hl
			call	disptextz
			
			; get rssi strength
				
			ld	hl,cmdrssi
			call	sendcmd
			ld	hl,msgsignal
			call	disptextz
			ld	a,(iy+3)
			call	disp_hex
			
			; get time
			
			ld	hl,msgtime
			call	disptextz
			
			ld	hl,cmdtime
			call	sendcmd
			push	iy
			pop	hl
			inc	hl
			inc	hl
			inc	hl
			call	disptextz
			
			; display version
			
			ld	hl,cmdver
			call	sendcmd
			push	iy
			pop	hl
			inc	hl
			inc	hl
			inc	hl
			call	disptextz
			
			call	crlf
			
			; get a socket
			
			ld	hl,cmdsocket
			call	sendcmd
			ld	a,(iy+3)
			cp	255
			ret	z
			
			; store socket in predefined packets
			
			ld	(lsocket),a	; listen socket
			ld	(bsocket),a	; bind socket
			ld	(asocket),a	; accept socket
			ld	(rsocket),a	; receive socket
			ld	(sendsock),a	; send socket
			ld	(sendsock2),a	; send socket (welcome)
			ld	(clsocket),a	; close socket
			
			; multiply by 16 and add to socket status buffer
			
			sla	a
			sla	a
			sla	a
			sla	a
			
			ld	hl,&FF06	; get sock info
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			ld	l,a
			ld	h,0
			add	hl,de	; sockinfo + (socket*4)
			push	hl
			pop	ix		; ix ptr to current socket status
			
			; bind to IP addr and port
			
			ld	hl,cmdbind	; fill in ip addr & port if predef not fitting.
			call	sendcmd
			ld	a,(iy+3)
			cp	0
			jp	nz, exit_close_error
			
			ld	hl,cmdlisten	; tell it to listen to above port and ip addr
			call	sendcmd
			ld	a,(iy+3)
			cp	0
			jp	nz, exit_close_error
		
			ld	hl,cmdaccept	; accept incoming connection..
			call	sendcmd
			ld	a,(iy+3)
			cp	0
			jp	nz, exit_close_error
			
			ld	hl,msgwait
			call	disptextz
			
			; wait for someone to connect!
wait_client:	call	&bb09
			jr	nc, notvalid
			cp	&fc				; ESC pressed?
			jp	z,exit_close	
notvalid:
			ld	a,(ix)			; get socket status  (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress, 3 = remote closed conn, 4 == wait incoming)
			cp	4				; incoming connection in progress?
			jr	z,wait_client
			cp	0
			jp	nz, exit_close_error
			
			ld	hl,msgconnected
			call	disptextz
			
			; send welcome greeting to client
			
			;ld	hl,cmdwelcome
			;call	sendcmd
			
			; display ip number
			
			ld	l,(ix+7)
			call	dispdec
			ld	a,&2e
			call	&bb5a
			ld	l,(ix+6)
			call	dispdec
			ld	a,&2e
			call	&bb5a
			ld	l,(ix+5)
			call	dispdec
			ld	a,&2e
			call	&bb5a
			ld	l,(ix+4)
			call	dispdec
			
			call	crlf
			
			; look for incoming data and display it
wait_recv:	call	&bb09
			jr	nc, notvalid1
			cp	&fc				; ESC pressed?
			jr	z,exit_close	
notvalid1:
			ld	bc,255	
			call	recv
			cp	&FF
			jr	z, exit_close	
			cp	3
			jr	z, exit_close
			xor	a
			cp	c
			jr	nz, got_msg
			cp	b
			jr	z,wait_recv	; keep looping, want a reply. Could do other stuff here!
got_msg:	
			
			; disp received msg
			ld	a,&3E
			call	&bb5a
			
			push	iy
			pop	hl
			
			ld	de,&6
			add	hl,de		; received text pointer
			
			; echo it back
			
			push	hl
			push	bc
			ld	de,sendtext
			ld	a,c
			ld	bc,250	; max size, prevent overflow because I am too lazy to re-write the sendcmd...
			ldir
			
			ld	hl,sendsize
			ld	(hl),a
			inc	hl
			ld	(hl),0
			ld	hl,cmdsend
			add	5			; add header size
			ld	(hl),a
			
			call	sendcmd
			pop	bc
			pop	hl
			
			; display it
			
			call	disptext
			call	crlf
			
			
			
			jp	wait_recv

exit_close_error:
			call	disp_error	
exit_close:
			ld	hl,cmdclose
			call	sendcmd			
			ret
			
			; recv tcp data
			; in
			; bc = receive size
			; out
			; a = receive status
			; bc = received size 

			
recv:		; connection still active
			ld	a,(ix)			; 
			cp	3				; socket status  (3 == remote closed connection)
			ret	z
			; check if anything in buffer ?
			ld	a,(ix+2)
			cp	0
			jr	nz,recv_cont
			ld	a,(ix+3)
			cp	0
			jr	nz,recv_cont
			ld	bc,0
			ld	a,1	
			ret
recv_cont:			
			; set receive size
			ld	a,c
			ld	(rsize),a
			ld	a,b
			ld	(rsize+1),a
			
			ld	hl,cmdrecv
			call	sendcmd
			
			ld	bc,0
			ld	a,(iy+3)
			cp	0				; all good ?
			jr	z,recv_ok
			push	af
			call	disp_error
			pop	af
			ld	bc,0
			ret

recv_ok:			
			ld	c,(iy+4)
			ld	b,(iy+5)
			ret
			
			
			;
			; Find M4 ROM location
			;
				
find_m4_rom:
			ld	iy,m4_rom_name	; rom identification line
			ld	d,127		; start looking for from (counting downwards)
			
romloop:		push	de
			;ld	bc,&DF00
			;out	(c),d		; select rom
			ld	c,d
			call	&B90F		; system/interrupt friendly
			ld	a,(&C000)
			cp	1
			jr	nz, not_this_rom
			
			; get rsxcommand_table
			
			ld	a,(&C004)
			ld	l,a
			ld	a,(&C005)
			ld	h,a
			push	iy
			pop	de
cmp_loop:
			ld	a,(de)
			xor	(hl)			; hl points at rom name
			jr	nz, not_this_rom
			ld	a,(de)
			inc	hl
			inc	de
			and	&80
			jr	z,cmp_loop
			
			; rom found, store the rom number
			
			pop	de			;  rom number
			ld 	a,d
			ld	(m4_rom_num),a
			ret
			
not_this_rom:
			pop	de
			dec	d
			jr	nz,romloop
			ld	a,255		; not found!
			ret
			
			;
			; Send command to M4
			;
sendcmd:
			ld	bc,&FE00
			ld	d,(hl)
			inc	d
sendloop:		inc	b
			outi
			dec	d
			jr	nz,sendloop
			ld	bc,&FC00
			out	(c),c
			ret
					
			; display text
			; HL = text
			; BC = length

disptext:		xor	a
			cp	c
			jr	nz, not_dispend
			cp	b
			ret	z
not_dispend:
			ld 	a,(hl)
			push	bc
			call	&BB5A
			pop	bc
			inc	hl
			dec	bc
			jr	disptext

			; display text zero terminated
			; HL = text
disptextz:	ld 	a,(hl)
			or	a
			ret	z
			call	&BB5A
			inc	hl
			jr	disptextz

			;
			; Display error code in ascii (hex)
			;
	
			; a = error code
disp_error:
			push	af
			ld	hl,msgsenderror
			ld	bc,9
			call	disptext
			pop	bc
disp_hex:		ld	a,b
			srl	a
			srl	a
			srl	a
			srl	a
			add	a,&90
			daa
			adc	a,&40
			daa
			call	&bb5a
			ld	a,b
			and	&0f
			add	a,&90
			daa
			adc	a,&40
			daa
			call	&bb5a
			ld	a,10
			call	&bb5a
			ld	a,13
			call	&bb5a
			ret

			; l = 8 bit number
dispdec:		ld	h,0
			ld	bc,-100
			call	Num1
			ld	c,-10
			call	Num1
			ld	c,b

Num1:		ld	a,'0'-1
Num2:		inc	a
			add	hl,bc
			jr	c,Num2
			sbc	hl,bc
			jp	&bb5a

crlf:		ld	a,10
			call	&bb5a
			ld	a,13
			jp	&bb5a
			
msgserver:	db	"********** TCP SERVER **********",10,13,0
msgsignal:	db	"Signal: &",0
msgtime:		db	"Time: ",0
msgwait:		db	10,13,"TCP server, waiting for client to connect...",10,13,0			
msgconnected:	db	10,13,"Client connected! IP addr: ",0
msgconnclosed:	db	10,13,"Remote closed connection....",10,13,0
msgsenderror:	db	10,13,"ERROR: ",0
cmdwelcome:	db	29
			dw	C_NETSEND
sendsock2:	db	0
			dw	24			
			db	10,13,"Welcome to M4 NET !",10,13,0
cmdnetstat:	db	2
			dw	C_NETSTAT
cmdrssi:		db	2
			dw	C_NETRSSI
cmdtime:		db	2
			dw	C_TIME
cmdver:		db	2
			dw	C_VERSION
cmdsocket:	db	5
			dw	C_NETSOCKET
			db	&0,&0,&6		; domain(not used), type(not used), protocol (TCP/IP)

cmdbind:		db	9
			dw	C_NETBIND
bsocket:		db	&0
bipaddr:		db	0,0,0,0		; IP 0.0.0.0 == IP_ADDR_ANY
bport:		dw	&1234		; port number

cmdlisten:	db	3
			dw	C_NETLISTEN
lsocket:		db	0

cmdaccept:	db	3
			dw	C_NETACCEPT
asocket:		db	0


cmdsend:		db	0			; we can ignore this byte (part of early design)	
			dw	C_NETSEND
sendsock:		db	0
sendsize:		dw	0			; size
sendtext:		ds	255
			
cmdclose:		db	&03
			dw	C_NETCLOSE
clsocket:		db	&0

cmdrecv:		db	5
			dw	C_NETRECV		; recv
rsocket:		db	&0			; socket
rsize:		dw	2048			; size
			
m4_rom_name:	db "M4 BOAR",&C4		; D | &80
m4_rom_num:	db	&FF
buf:			ds	255	
