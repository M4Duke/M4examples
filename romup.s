			;
			; Example of using M4 direct file I/O
			; to upload a new rom
			;
			; Duke 2018 - spinpoint.org
			;
			; Assembled with RASM (www.roudoudou.com/rasm)
			
			; commands
				
C_OPEN						equ 0x4301
C_READ						equ 0x4302
C_WRITE						equ 0x4303
C_CLOSE						equ 0x4304
C_SEEK						equ 0x4305

C_ROMSUPDATE				equ	0x432B
			; fat defs
FA_READ 					equ	1
FA_WRITE					equ	2
FA_CREATE_NEW				equ 4
FA_CREATE_ALWAYS			equ 8
FA_OPEN_ALWAYS				equ 16
FA_REALMODE					equ 128
			
DATAPORT					equ 0xFE00
ACKPORT						equ 0xFC00
			org	0x4000
rom_addr:
			incbin	"protext.rom"		; use binary (no amsdos header) rom file here
			
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
			ld		iy, cmd_buf		; buffer used for all file functions

			call	m4rom_enable	; enable m4 rom at 0xC000, functions below assume its paged in.
			
			; get rom_response address from rom_table at 0xFF02
			
			ld		hl,0xFF02
			ld		e,(hl)
			inc		hl
			ld		d,(hl)
			push	de
			pop		ix
			
			; ix points to rom response, used by functions below
			
			ld		a,2				; rom slot to be flashed
			ld		hl, rom_addr	; address of rom data
			call	write_rom

			; more roms could be written here
			
			; and finally tell m4 to update the flash internally
			
			call	update_roms

			; the end

			call	m4rom_disable
			ei
			call	0xbb18
			
			; done..
			
			jp		0
			
			
			
			; -- a = rom slot
			; -- hl = address of rom to be flashed
			
write_rom:			
			; open m4/romslots.bin
			ld		(iy-2),a		; roms slot
			ld		(rom_addr_ptr),hl
			ld		hl, romslots_fn
			ld		c,0x80 | FA_READ|FA_WRITE
			ld		a,17
			ld		de, C_OPEN
			call	send_command2	; will do cmd(2, DE), size(1, A), mode (1, C) followed by data in HL with A size.
			ld		b,(ix+3)		; fd
			ld		a,(ix+4)		; res
			
			cp		0
			jp		nz, romupload_fail
			
			ld		(iy-1),b				; file handle
			
			; calculate seek offset

			ld		bc,0x4000		; rom size
			
			ld		e, (iy-2)	;  rom slot
			ld		d,0
			call	mul16		; performs DEHL = BC*DE
			
			; perform fseek (32 bit) offset into m4/romslots.bin
			
			ld	(iy+0),7			; size.. cmd(2) + fd (1) + offset (4)
			ld	(iy+1),C_SEEK		; cmd seek
			ld	(iy+2),C_SEEK>>8	; cmd seek
			ld	a,(iy-1)			; file handle
			ld	(iy+3),a			; 
			ld	(iy+4),l			; offset
			ld	(iy+5),h			; offset
			ld	(iy+6),e			; offset
			ld	(iy+7),d			; offset
			
			call	send_command_iy
			
			ld	a,(ix+3)	; check if seek was OK?
			or	a
			jp	nz, romupload_close_fail

			
			; write the ROM in 252 byte chunks to m4/romslots.bin 
			
			ld		hl, (rom_addr_ptr)
			ld		b, 65			; 65 * 252 = 16380
			
			; write chunk size to outputfile (romslots.bin)

			
rom_write_loop:
			push	bc
			ld		bc, DATAPORT				; data out port
			ld		de, C_WRITE					; command
			ld		a,255
			out		(c),a						; size 
			out		(c),e						; command lo (C_WRITE)
			out		(c),d						; command hi (C_WRITE)
			ld		e,(iy-1)					; file handle
			out		(c),e
			sub		3							; size - 3
rom_data_loop:
			inc		b
			outi
			dec		a
			jr		nz, rom_data_loop
			ld	bc,ACKPORT						; kick the command
			out (c),c
		
			pop		bc
			djnz	rom_write_loop
			
			
			; and write the remaining 16384-16380= 4 bytes
			
			ld		bc, DATAPORT				; data out port
			ld		de, C_WRITE					; command
			ld		a,7
			out		(c),a						; size 
			out		(c),e						; command lo (C_WRITE)
			out		(c),d						; command hi (C_WRITE)
			ld		e,(iy-1)					; file handle
			out		(c),e
			inc		b
			outi
			inc		b
			outi
			inc		b
			outi
			inc		b
			outi
				
		
			ld	bc,ACKPORT						; kick the command
			out (c),c
		
			; close	the file
			
			ld		a,(iy-1)			; file handle for "m4/romslots.bin"
			call	fclose
			
			; now update m4/romconfig.bin
			
			ld	hl, romconfig_fn
			ld	c,0x80 | FA_READ|FA_WRITE
			ld	a,18
			ld	de, C_OPEN
			call	send_command2	; will do cmd(2, DE), size(1, A), mode (1, C) followed by data in HL with A size.
			ld	b,(ix+3)		; fd
			ld	a,(ix+4)		; res
			
			cp	0xFF
			jp	z, romupload_fail
		
			ld	(iy-1),b	; file handle
			
		
			ld	bc,33		; rom name (32) + updateflag (1)
			
			ld	e, (iy-2)	;  rom slot
			ld	d,0
			call	mul16		; performs DEHL = BC*DE
			ld	de,32		; skip header (8*4)
			add	hl,de		; size is less than 16 bit, no worries..
			
			ld	a, (iy-1)
			call fseek		; we are now pointing at the updateflag for current rom slot
				
			; set update flag to 2 and name to "rom".
			
			ld	de, C_WRITE
			ld	hl, update_rom_slot	; data read earlier
			ld	c, (iy-1)
			ld	a, 5
			call	send_command2	; will do cmd(2, DE), size(1, A), fd (1, C) followed by data in HL with A size.
			
			ld	a, (iy-1)
			call	fclose
			xor	a					; success.
			ret			
			
		
romupload_close_fail:
			ld		a,(iy-1)			; file handle "m4/romslots.bin"
			call	fclose
romupload_fail:
			ld		a,255			; fail
			ret	

update_roms:
			ld	(iy+1),C_ROMSUPDATE
			ld	(iy+2),C_ROMSUPDATE>>8
			ld	(iy+0),2			; packet size, cmd (2)
			call	send_command_iy
			ret	
			
			
			
			; fopen
			
			; ------------------------- fopen
			; -- parameters: 
			; -- IY = buffer to store command
			; -- HL = filename
			; -- B = filename length
			; -- A = mode
			; -- return:
			; -- A = file fd (255 if error!)
			; -- B = error code
fopen:
			push	bc
			push	de
			push	hl
			ld		(iy+1),C_OPEN
			ld		(iy+2),C_OPEN>>8
			ld		(iy+3),a			; mode
			add		3			; cmd (2) + mode (1) + filename
			ld		(iy),a			; packet length
			call	send_command_iy
			
			ld		a,(ix+4)	; check if open was OK?
			cp		0
			jr		nz, fd_not_ok
			ld		a,(ix+3)	; file descriptor 
fd_not_ok:
			pop		hl
			pop		de
			pop		bc
			ret
		

			; ------------------------- fread
			; -- parameters: 
			; -- A = fd
			; -- IY = buffer to store command
			; -- HL = size
			; -- DE = addr
			; -- return:
			; -- A = 0 if OK
fread:
			push	hl
			push	de
			push	bc
			ld	(iy+1),C_READ
			ld	(iy+2),C_READ>>8
			ld	(iy+3),a				; fd
			ld	(iy+0),5				; packet size, cmd (2), fd (1), size (2)

read_loop:
			; get chunk size (<=0x800)
			
			push	hl
			ld	bc,-0x800
			add	hl,bc				; and substract chunksize
			jp	c, full_chunk
			pop 	hl
			ld	(iy+4),l				; chunk size low
			ld	(iy+5),h				; chunk size high
			jr	fread_cont
	
full_chunk:
			pop	hl
			ld	(iy+4),0x0			; chunk size low
			ld	(iy+5),0x8			; chunk size high
fread_cont:
			xor	a
			cp	(iy+4)
			jr	nz,not_done			; size is 0?
			cp	(iy+5)
			jr	nz,not_done			; size is 0?
			pop	bc
			pop	de
			pop	hl
			xor	a
			ret
not_done:
			push	hl
			call	send_command_iy	; send read command packet
			ld	c,(iy+4)			; chunk size low
			ld	b,(iy+5)			; chunk size high
			
			ld	a,(ix+3)			; check result
			cp	0
			jr	nz,read_error
			inc	hl
			push	bc				; store chunk size
			ldir					; copy data in place
			pop	bc				; restore chunk size
			pop	hl				; restore remaining size
			or	a				; clear carry
			sbc	hl,bc			; and substract chunksize
			jr	read_loop
read_error:
			pop	hl
			pop	bc
			pop	de
			pop	hl
			ret

			; ------------------------- fseek
			; -- parameters:
			; -- IY = buffer to store command
			; -- A = fd 
			; -- HL = offset
fseek:
			push	bc
			push	hl
			push	de
			ld	(iy+0),7			; size.. cmd(2) + offset (4)
			ld	(iy+1),C_SEEK		; cmd seek
			ld	(iy+2),C_SEEK>>8	; cmd seek
			ld	(iy+3),a			; fd
			ld	(iy+4),l			; offset lo
			ld	(iy+5),h			; offset hi
			ld	(iy+6),0			; 0
			ld	(iy+7),0			; 0
			call	send_command_iy
			
			pop	de
			pop	hl
			pop	bc
			ret

			; ------------------------- fclose
			; -- parameters:
			; -- IY = buffer to store command			
			; -- A = file fd
			; -- return
			; -- A = 0, good. A = 0xFF bad.
fclose:
			push	bc
			push	hl
			ld	(iy+1),C_CLOSE		; close cmd
			ld	(iy+2),C_CLOSE>>8	; close cmd
			ld	(iy+3),a			; fd
			ld	(iy+0),3		; size - cmd(2) + fd(1)
			call send_command_iy
			ld	a,(ix+3)
			cp	0
			jr	z,fclose_ok
			ld	a,255		
fclose_ok:	
			pop	hl
			pop	bc
			ret

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

mul16:		ld	hl,0
			ld	a,16
mul16Loop:	add	hl,hl
			rl	e
			rl	d
			jp	nc,nomul16
			add	hl,bc
			jp	nc,nomul16
			inc	de
nomul16:
			dec	a
			jp	nz,mul16Loop
			ret
			
			; DE = COMMAND			
			; A = size 
			; HL = DATA
			; C = fd
send_command2:
			push	af
			push	hl
			push	de
			push	bc
			add	3
			ld	bc,DATAPORT					; data out port
			out	(c),a						; size
			out	(c),e						; command lo
			out	(c),d						; command	hi
			pop	de
			push	de
			out	(c),e						; fd
			sub	3
			; send actual data
			
sendloop2:
			ld	d,(hl)
			out	(c),d
			inc	hl
			dec	a
			jr	nz, sendloop2
			
			; tell M4 that command has been send
			ld	bc,ACKPORT
			out (c),c
			pop	bc
			pop	de
			pop	hl
			pop	af
			ret

send_command_iy:
			push	iy
			pop	hl
			ld	bc,DATAPORT	;0xFE00			; FE data out port
			ld	a,(hl)						; size
			inc	a
sendloop_iy:
			inc	b
			outi
			dec	a
			jr	nz, sendloop_iy
			
			; tell M4 that command has been send
		
			ld	bc,ACKPORT
			out (c),c
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

			
			
update_rom_slot:
			db  2
			db "ROM"			; change to any name you want, this will be displayed in the webinterface.
			db	0
romslots_fn:
			db "/m4/romslots.bin"
			db	0
romconfig_fn:
			db "/m4/romconfig.bin"
			db	0

m4_rom_name:	db "M4 BOAR",0xC4		; D | 0x80
m4_rom_num:	db	0xFF

rom_addr_ptr:
			dw	0
rom_slot:
			db	0
file_handle:
			db 	0				; iy - 1
cmd_buf:	ds	256				; iy