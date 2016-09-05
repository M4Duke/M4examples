
			; DNS lookup example for M4 Board
			; Requires firmware v1.0.9b8 upwards
			; Duke 2016
			
			org	&4000
			nolist
DATAPORT		equ &FE00
ACKPORT		equ &FC00			

C_NETHOSTIP	equ &4336
			
start:		push	iy
			push	ix

			ld	a,(m4_rom_num)
			cp	&FF
			call	z,find_m4_rom	; find rom (only first run)
							; should add version check too and make sure its v1.0.9
			cp	&FF
			call	nz,dnslookup
			
			pop	ix
			pop	iy
			ret
	
dnslookup:	ld	hl,&FF02	; get response buffer address
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
			

			ld	hl,cmdlookup
			call sendcmd
			ld	a,(iy+3)
			cp	1
			jr	z,wait_lookup
			call	disp_error
			
			jp	&bb18
			
wait_lookup:
			ld	a,(ix+0)
			cp	5			; ip lookup in progress
			jr	z, wait_lookup
			cp	0			; ip found ?
			jr	z,ip_found
			call	disp_error
			jp	&bb18

			; resolved to ip, display on screen
ip_found:
			ld	hl,msgresolv
			call	disptextz			
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
			jp	&bb18
			


			
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


			; l = 8 bit number
dispdec:		ld	h,0
			ld	bc,-100
			call	Num1
			ld	e,a
			cp	'0'
			call	nz,&bb5a		; dont display leading zero
			ld	c,-10
			call	Num1
			cp	'0'
			jr	nz, nextnum
			cp	e			; was previous 0 too ?
nextnum:		call	nz,&bb5a
			
			ld	c,b
			call	Num1
			jp	&bb5a

Num1:		ld	a,'0'-1
Num2:		inc	a
			add	hl,bc
			jr	c,Num2
			sbc	hl,bc
			ret
			



msgsenderror:	db	10,13,"ERROR: ",0
msgresolv:	db	10,13,"Resolved to IP: ",0
cmdlookup:	db	16
			dw	C_NETHOSTIP
			db	"spinpoint.org",0


m4_rom_name:	db "M4 BOAR",&C4		; D | &80
m4_rom_num:	db	&FF
