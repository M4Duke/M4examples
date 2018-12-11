		; M4 rom re-config
		; To assemble use RASM assembler
		; Duke - 2018
		
		org	0x4000
		nolist

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
		
		; read romconfig.bin
		
		ld	hl,filename
		ld	de,buf
		ld	b,13		; "romconfig.bin"
		call cas_in_open
		jp	nc,file_err
		ld	hl, buf2
		ld	bc,1088		; file len
fread_loop:
		call cas_in_char
		ld	(hl),a
		inc	hl
		dec	bc
		xor	a
		cp	c
		jr	nz, fread_loop
		cp	b
		jr	nz, fread_loop
		
		call cas_in_close
		
		; display 'active' roms and set the flag so they are re-flashed on power cycle
		
		ld	ix,buf2
		ld	b,(ix)		; number of roms (either 16 or 32)
		ld	de,32
		add	ix,de		; skip header
		inc	de
rom_loop:
		ld	a,(ix)
		cp	1
		jr	nz, rom_not_used
		push de
		push ix
		pop	hl
		push bc
		inc hl			; point to rom name
		ld de,text_buf
		ld bc,32
		ldir
		pop bc
		pop de
		ld hl,text_buf
		call wrt
		ld hl,txt_reen
		call wrt
		ld (ix),2		; set rom to NEW
rom_not_used:
		add	ix,de		; +33
		djnz rom_loop
		
		; save the modified romconfig.bin
		
		ld hl,filename
		ld de,buf
		ld b,13		; "romconfig.bin"
		call cas_out_open
		ld hl,buf2
		ld bc,1088		; file len
fwrite_loop:
		ld	a,(hl)
		call cas_out_char
		inc hl
		dec bc
		xor a
		cp c
		jr nz, fwrite_loop
		cp b
		jr nz, fwrite_loop
		
		call cas_out_close
done:
		; display done
		
		ld hl,txt_done
		call wrt
		jp	km_wait_key
file_err:
		ld	hl,txt_file_err
		call wrt
		jp	km_wait_key
wrt:
		ld	a,(hl)
		or	a
		ret	z
		call txt_output
		inc	hl
		jr	wrt
		
filename:
		db "romconfig.bin"
txt_title:
		db "M4 rom reconfig - Duke 2018",10,13,10,13,0
txt_file_err:
		db "Error M4 romconfig.bin not found!",10,13,0
txt_reen:
		db " re-enabled.",10,13,0
txt_done:
		db 10,13,10,13,"Done! Power-cycle CPC",0

text_buf:
		ds 33,0
		
buf:	ds 2048,0
buf2:	ds 1088,0	