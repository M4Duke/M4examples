
			; HTTP get example for M4 Board
			; Requires firmware v1.0.9 upwards
			; Duke 2016
			
			org	&4000
			nolist
DATAPORT		equ &FE00
ACKPORT		equ &FC00			
C_NETSOCKET	equ &4331
C_NETCONNECT	equ &4332
C_NETCLOSE	equ &4333
C_NETSEND		equ &4334
C_NETRECV		equ &4335
C_NETHOSTIP	equ &4336
			
			ld	a,2			
			call	&bc0e		; set mode 2
			push	iy
			push	ix

			ld	a,(m4_rom_num)
			cp	&FF
			call	z,find_m4_rom	; find rom (only first run)
							; should add version check too and make sure its v1.0.9
			cp	&FF
			call	nz,httpget
			
			pop	ix
			pop	iy
			ret
	
httpget:		ld	hl,&FF02	; get response buffer address
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			push	de
			pop	iy
			ld	hl,&FF06	; get sock info
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			push	de
			pop	ix		; ix ptr to current socket status

			; translate hostname to ip addr
			
			call	dnslookup
			cp	0
			ret	nz		; error!
			
			; get a socket
			
			ld	hl,cmdsocket
			call	sendcmd
			ld	a,(iy+3)
			cp	255
			ret	z
			
			; store socket in predefined packets
			
			ld	(csocket),a
			ld	(clsocket),a
			ld	(rsocket),a
			ld	(sendsock),a
			
			
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
			
			; connect to server
			
			ld	hl,cmdconnect
			call	sendcmd
			ld	a,(iy+3)
			cp	255
			jp	z,exit_close
wait_connect:
			ld	a,(ix)			; get socket status  (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress)
			cp	1				; connect in progress?
			jr	z,wait_connect
			cp	0
			jr	z,connect_ok
			call	disp_error	
			jp	exit_close
connect_ok:	
			; send httpget request

			ld	hl,cmdsend
			call	sendcmd

wait_send:	ld	a,(ix)
			cp	2			; send in progress?
			jr	z,wait_send	; Could do other stuff here!
			cp	0
			call	nz,disp_error	
			

			; receive

wait_recv:			
			ld	bc,2048		; 2048 is max size we can receive in one go (smaller buffer is fine...)	
			call	recv
			cp	&FF
			jr	z, exit_close
			xor	a
			cp	c
			jr	nz, got_msg
			cp	b
			jr	z,wait_recv
			
got_msg:	
					
			; disp received msg
			push	iy
			pop	hl
		
			; string parsing to get past http headers, should go here
		
			ld	de,&6
			add	hl,de		; received text pointer
			call	disptext
		
			; check if there is more in buffer to receive ?
			
			ld	a,(ix+2)
			cp	0
			jr	nz,wait_recv	; there is more?
			ld	a,(ix+3)
			cp	0
			jr	nz,wait_recv	; there is more?
			
			; ok, that's it lets close the connection gracefully.
			
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

			
recv:		; check if anything in buffer ?
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
			
			ld	a,(iy+3)
			cp	0				; all good ?
			jr	z,recv_ok
			ld	bc,0
			ret

recv_ok:			
			ld	c,(iy+4)
			ld	b,(iy+5)
			ret
			
			; parameters hardcoded in request
dnslookup:			
			ld	hl,cmdlookup
			call sendcmd
			ld	a,(iy+3)
			cp	1
			jp	nz,disp_error
			
wait_lookup:
			ld	a,(ix+0)
			cp	5			; ip lookup in progress
			jr	z, wait_lookup
			cp	0			; ip found ?
			jp	nz,disp_error
			
			; resolved to ip, store in request packet
ip_found:		ld	a,(ix+4)
			ld	(ip_addr),a
			ld	a,(ix+5)
			ld	(ip_addr+1),a
			ld	a,(ix+6)
			ld	(ip_addr+2),a
			ld	a,(ix+7)
			ld	(ip_addr+3),a
			xor	a
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
			ld	a,b
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
			
msgsenderror:	db	10,13,"ERROR: ",0


cmdsocket:	db	5
			dw	C_NETSOCKET
			db	&0,&0,&6		; domain, type, protocol (TCP/ip)

cmdconnect:	db	9	
			dw	C_NETCONNECT
csocket:		db	&0
ip_addr:		db	0,0,0,0		; ip addr
			dw	80			; port

cmdsend:		db	74+5			; we could ignore this byte (part of early design) with a sendcommand that doesn't use it.
			dw	C_NETSEND
sendsock:		db	0
sendsize:		dw	74			; size
sendhttpreq:	db "GET /cpc/m4info.txt HTTP/1.0", 13,10		; 30
			db "Host: www.spinpoint.org",13,10				; 25
			db "User-Agent: m4",13,10,13,10				; 19 = 74

cmdclose:		db	&03
			dw	C_NETCLOSE
clsocket:		db	&0

cmdlookup:	db	20
			dw	C_NETHOSTIP
			db	"www.spinpoint.org",0

cmdrecv:		db	5
			dw	C_NETRECV		; recv
rsocket:		db	&0			; socket
rsize:		dw	2048			; size
			
m4_rom_name:	db "M4 BOAR",&C4		; D | &80
m4_rom_num:	db	&FF
buf:			ds	2048	
