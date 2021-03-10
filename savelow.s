		; Duke - 2021
		;
		; Lower rom(s) dumper (assemble with RASM)
		; Short example of using the newly introduced C_ROMLOW (0x433D) command in v.2.0.7 firmware
		; With this you can toggle between the SYSTEM lower rom, the M4 board lower rom and the HACK-menu lower rom
		;
		
		
		org	0x4000
		nolist
DATAPORT		equ 0xFE00
ACKPORT			equ 0xFC00		

km_wait_key		equ 0xBB18
txt_output		equ 0xBB5A
txt_set_column	equ 0xBB6F
scr_reset		equ	0xBC0E
scr_set_ink		equ	0xBC32
scr_set_border	equ	0xBC38
cas_in_open		equ 0xBC77
cas_in_close	equ 0xBC7A
cas_in_char		equ 0xBC80
cas_out_open	equ 0xBC8C
cas_out_close	equ 0xBC8F
cas_out_char	equ 0xBC95
cas_out_direct	equ 0xBC98
kl_init_back	equ 0xBCCE

		; re-init M4rom
	
		ld de,0x40 
		ld hl,0xB0FF
		call 0xBCCB
		
		
		; setup screen
		
		ld a,2			
		call scr_reset		; set mode 2
		xor a
		ld b,a
		call scr_set_border
		xor a
		ld b,a
		ld c,b
		call scr_set_ink
		ld a,1
		ld b,26
		ld c,b
		call scr_set_ink

		ld	a,20
		call txt_set_column
		ld	hl,txt_title
		call wrt

		

		ld	a,2
		call copy_lower_rom
		ld hl,filename3
		call save_file	
		
		ld	a,1
		call copy_lower_rom
		ld hl,filename2
		call save_file
		
		ld	a,0
		call copy_lower_rom
		ld hl,filename1
		call save_file		
		
		
		ld hl,txt_done
		call wrt
		jp	km_wait_key					; wait and reset
		
		; copy lowerrom to 0x5000
		
copy_lower_rom:
		di
		ld	de,0x433D					; C_ROMLOW 
		ld	bc,DATAPORT					; data out port
		out	(c),c						; ignore size, its not used.
		out	(c),e						; command lo
		out	(c),d						; command	hi
		out	(c),a						; 0 = system lower, 1 = m4 board loader, 2 = hack rom
		ld	bc,ACKPORT
		out	(c),c
		
		ld bc,0x7F8A					; enable lowerrom
		out (c),c
		
		ld 	hl,0
		ld	de,0x5000
		ld 	bc,0x4000
		ldir
		
		xor a
		
		ld	de,0x433D					; C_ROMLOW 
		ld	bc,DATAPORT					; data out port
		out	(c),c						; ignore size, its not used.
		out	(c),e						; command lo
		out	(c),d						; command	hi
		out	(c),a						; 0 = system lower
		ld	bc,ACKPORT
		out	(c),c
		ld bc,0x7F8E
		out (c),c						; disable lowerrom
		ei
		ret	
		
		
save_file:
		ld de,buf
		ld b,12
		call cas_out_open
		ld hl,0x5000	; addr
		ld de,0x4000	; len
		ld bc,0			; exec
		ld a,2			; bin
		call cas_out_direct
		call cas_out_close
		ret
		


wrt:
		ld	a,(hl)
		or	a
		ret	z
		call txt_output
		inc	hl
		jr	wrt
		
filename1:
		db "rom-lsys.rom"
filename2:
		db "rom-lwm4.rom"
filename3:
		db "rom-hack.rom"

txt_title:
		db "Lower rom(s) dumper - Duke 2021",10,13,10,13,0
txt_done:
		db 10,13,10,13,"Done! Power-cycle CPC",0
buf:	ds 2048
