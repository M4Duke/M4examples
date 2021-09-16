			;
			; Example of using M4 direct I/O for getting directory contents
			;
			; Duke 2021 - spinpoint.org
			;
			; Assembled with RASM (www.roudoudou.com/rasm)
			
			; commands

C_READDIR					equ 0x4306
C_DIRSETARGS				equ 0x4325
C_NMI			            equ 0x431D	

DATAPORT					equ 0xFE00
ACKPORT						equ 0xFC00


dir_buffer equ 0x4000
			
			
			
			org 0x8000

			; find rom M4 rom number
						

			ld		a,(m4_rom_num)
			cp		0xFF			; if not 0xFF its already initilized, no need to waste time....
			call	z,find_m4_rom	
			cp		0xFF
			jr		nz,found_m4				; M4 rom not detected, crash and burn :/
			ld		a,7
			call	0xbb5a					; beep
			jp		0xbb18
found_m4:			
			di
			
			call	m4rom_enable	; enable m4 rom at 0xC000, functions below assume its paged in.

	

			; get rom_response address from rom_table at 0xFF02
			
			ld		hl,0xFF02
			ld		e,(hl)
			inc		hl
			ld		d,(hl)
			push	de
			pop		ix
			

			; ix points to rom response, used by functions below
			
			ld		hl, dir_buffer
			call	gen_directory

			; now we could add some code to display the directory from the buffer at 0x4000
			; but since I am lazy I will just start the HACK menu and you can view the memory there to check ;)

			
						
			ld	bc,DATAPORT
			out	(c),c						
			ld	de, C_NMI
			out	(c),e						; command lo
			out	(c),d						; command	hi
			
			ld	bc,ACKPORT
			out (c),c	
			

			call	m4rom_disable
			ei
			call	0xbb18
			
			; done..
			
			jp		0
			

dir_name:	db "m4/"
			db 0
			
gen_directory:			
			push hl

			; --- set path & wildcards (none here) to retrieve the directory from
			
			ld 	de, C_DIRSETARGS
			ld	hl, dir_name
			ld	a,4+2
			ld	bc,DATAPORT
			out	(c),a						; size
			out	(c),e						; command lo
			out	(c),d						; command	hi
			
			sub	2
			
			; send the path
			
sendloop_dirname:
			ld	d,(hl)
			out	(c),d
			inc	hl
			dec	a
			jr	nz, sendloop_dirname
			ld	bc,ACKPORT
			out (c),c						; go



			pop de							; dest mem address
			push ix
			pop  hl
			ld bc, 3
			add hl,bc						; rom src address

			
dir_loop:
			ld	bc,DATAPORT
			ld	a, 3
			out	(c),a						; size
			ld	a,C_READDIR & 0xFF
			out	(c),a						; command lo
			ld	a,C_READDIR >> 8
			out	(c),a						; command hi
			ld	a, 80
			out	(c),a						; set max filename/directory length to 80
			
			ld	bc,ACKPORT
			out (c),c						; go
			

			ld	a,(ix)					; check if 2, then its last directory entry.
			cp	2
			ret z						; last entry received ?
			ld b,0
			ld c,a
			push hl
			ldir						; copy from rom receive buffer, to ram
			pop hl						; retain src buffer
		
			jr	dir_loop				; get next entry

find_m4_rom:
			
			ld	d,127		; start looking for from (counting downwards)
			
romloop:	push	de
			ld		c,d
			call	0xB90F		; system/interrupt friendly
			ld		a,(0xC000)
			cp		1
			jr		nz, not_this_rom
			ld		hl,(0xC004)	; get rsxcommand_table
			ld		de,m4_rom_name	; rom identification line
cmp_loop:
			ld		a,(de)
			xor		(hl)			; hl points at rom name
			jr		z, match_char
not_this_rom:
			pop		de
			dec		d
			jr		nz, romloop
			ld		a,255		; not found!
			ret
			
match_char:
			ld		a,(de)
			inc		hl
			inc		de
			and		0x80
			jr		z,cmp_loop
			
			; rom found, store the rom number
			
			pop	de			;  rom number
			ld 	a,d
			ld	(m4_rom_num),a
			ret

m4rom_enable:
			; rom select
			
	
			ld	a,(m4_rom_num)
			ld	bc,0xDF00
			out	(c),a
			
			; enable upperrom
			
			ld	bc,0x7F86
			out	(c),c
			ret

m4rom_disable:
			
			; diable upperrom (and lower)
			
			ld	bc,0x7F8E
			out	(c),c
			ret

			


m4_rom_name:	db "M4 BOAR",0xC4		; D | 0x80
m4_rom_num:	db	0xFF

