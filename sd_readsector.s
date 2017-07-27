			org	&9000
			nolist
DATAPORT		equ &FE00
ACKPORT		equ &FC00			
C_SDREAD		equ &4314
C_SDWRITE		equ &4315			
			di
			push	iy
			push	ix
			ld	bc,&7F86
			out	(c),c

			ld	a,(m4_rom_num)
			cp	&FF
			call	z,find_m4_rom	; find rom (only first run)
			cp	&FF			; was it found at all?
			call	nz,read_sector
			ld	bc,&7F8E
			out	(c),c
			ld	bc,&DF00
			out	(c),c
			
			pop	ix
			pop	iy
			ei
			ret
read_sector:						; a = rom number
			ld	bc,&DF00
			out	(c),a
			ld	hl,&FF02	; get response buffer address
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			push	de
			pop	iy
			
			; read LBA 0, len 1 sector
			
			ld	hl,cmdsdread
			call	sendcmd			
			ld	a,(iy+3)
			cp	0
			ret	nz		; error occurred.
			
			; display hexcodes
			
			push	iy
			pop	hl
			ld	de,4
			add	hl,de	; skip header
			ld	e,16		; 16 rows
row_loop:		ld	d,32		; 32 columns = 512

column_loop:
			ld	a,(hl)
			inc	hl
			call	disp_hex
			dec	d
			jr	nz, column_loop
			ld	a,10
			call	&bb5a
			ld	a,13
			call	&bb5a
			dec	e
			jr	nz, row_loop
			
			; wait keypress
			
			call	&bb18
			
			ret
			
		
find_m4_rom:
			di
			ld	iy,m4_rom_name	; rom identification line
			ld	d,127		; start looking for from (counting downwards)
			
romloop:		push	de
			ld	bc,&DF00
			out	(c),d		; select rom
			
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

			
			
			; a = input val
disp_hex:		ld	b,a
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
			ret
			
	
cmdsdread:	db	7
			dw	C_SDREAD
			db	0,0,0,0			; physical LBA
			db	1				; num sectors

m4_rom_name:	db "M4 BOAR",&C4		; D | &80
m4_rom_num:	db	&FF
buf:			ds	512	
