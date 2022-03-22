			;
			; Simple example of using M4 direct file I/O
			; to write a file, read it back and display the contents.
			;
			; Duke 2022 - spinpoint.org
			;
			; Assembled with RASM (www.roudoudou.com/rasm)
			
			; commands
				
C_OPEN						equ 0x4301
C_READ						equ 0x4302
C_WRITE						equ 0x4303
C_WRITE2					equ 0x431B
C_CLOSE						equ 0x4304
C_SEEK						equ 0x4305
C_ROMLOW                    equ 0x433D

			; fat defs
FA_READ 					equ	1
FA_WRITE					equ	2
FA_CREATE_NEW				equ 4
FA_CREATE_ALWAYS			equ 8
FA_OPEN_ALWAYS				equ 16
FA_REALMODE					equ 128
			
DATAPORT					equ 0xFE00
ACKPORT						equ 0xFC00

km_wait_key		equ 0xBB18
txt_output		equ 0xBB5A
txt_set_column	equ 0xBB6F
scr_reset		equ	0xBC0E
scr_set_ink		equ	0xBC32
scr_set_border	equ	0xBC38

			org	0x8000
rom_addr:

			; re-init M4rom
		
			ld de,0x40 
			ld hl,0xB0FF
			call 0xBCCB
			
			; setup screen
			
			ld a,1			
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


			di

			call	m4rom_enable	; detect and enable m4 rom at 0xC000, functions below assume its paged in.
			cp		255
			jr		nz, is_ok
			ld		hl,txt_error
			call	wrt
			jp		error
is_ok:
			
			; ----------------------------------------------------------------
			; write a filename "test.asc" with contents "Hello World!",0
			; ----------------------------------------------------------------
			
			
			; open file
			
			ld		hl,fname
			
			ld		a, FA_REALMODE | FA_CREATE_ALWAYS | FA_WRITE
			call	fopen
			cp		255
			jr		z, error
			
			; write the file
			
			push	af	; save filehandle
			
			ld		hl,data
			ld		bc, 13
			call	fwrite
			
			; close the file
			
			pop		af
			call	fclose

			
			; ----------------------------------------------------------------
			; read the file "test.asc" and display contents
			; ----------------------------------------------------------------
			
	
			
			; open file
			
			ld		hl,fname
			ld		a,FA_REALMODE | FA_READ
			call	fopen
			cp		255
			jr		z, error
			
	
			
			ld		hl,buffer	
			ld		bc,13		; size
			
			push	af			; fd
			call	fread
			cp		0
			jr		nz, error
			
			pop		af			;fd	
			call	fclose
			
			
			; display the contents
			
			call	m4rom_disable
			ld		hl,buffer
			call	wrt
			
		
endl:		jp endl
error:		ld		a,7
			call	0xbb5a
			jp		endl	

data:		db 		"Hello world!",0

			; ------------------------- fopen
			; -- parameters: 
			; -- HL = filename zero terminated
			; -- A = mode
			; -- return:
			; -- A = file fd (255 if error!)

fopen:
			ld	bc,DATAPORT
			out	(c),c			; ignore first byte
			ld	de,C_OPEN
			out	(c),e
			out	(c),d
			out	(c),a		; mode
	
			; filename
send_fn:
			ld a,(hl)
			inc hl
			out (c),a
			or a
			jr nz, send_fn
		
			ld		b,ACKPORT>>8	; kick command
			out		(c),c
			
			ld		hl,(0xFF02)
			inc		hl
			inc		hl
			inc		hl
			inc		hl
			ld		a,(hl)			; check if open was OK?
			cp		0
			jr		nz, fd_not_ok
			dec		hl
			ld		a,(hl)
fd_not_ok:
			ret
			
			

			; ------------------------- fread
			; -- parameters: 
			; -- A = fd
			; -- HL = addr
			; -- BC = size  (max. 2048 at a time)
			; -- return:
			; -- A = 0 if OK
fread:		push	bc
			ld		bc,DATAPORT
			out		(c),c			; ignore first byte
			ld		de,C_READ
			out		(c),e
			out		(c),d
			out		(c),a		; fd
			pop		de			
			push	de
			out		(c),e		; size
			out		(c),d		; size
			
			ld		b,ACKPORT>>8	; kick command
			out		(c),c
			ex		de,hl			; address in ram
			ld		hl,(0xFF02)
			inc		hl
			inc		hl
			inc		hl
			ld		a,(hl)			; response
			inc		hl				; point at data in rombuffer
			pop		bc				; size
			ldir
			ret

			; ------------------------- fwrite
			; -- parameters: 
			; -- A = fd
			; -- HL = addr
			; -- BC = size  (max. 65536 at a time)
			; -- return:
			; -- A = 0 if OK
			
fwrite:		push	bc
			ld		bc, DATAPORT				; data out port
			out		(c),c						; 
			ld		de, C_WRITE2				; command  (only for REAL MODE, but takes 16 bit size at once)
			out		(c),e						; command lo (C_WRITE2)
			out		(c),d						; command hi (C_WRITE2)
			out		(c),a						; file handle
			pop		de
			out		(c),e						; size low byte
			out		(c),d						; size high byte

wr_loop:
			
			inc		b
			outi
			
			dec		de
			xor		a
			cp		d
			jr		nz, wr_loop
			cp		e
			jr		nz, wr_loop
			
			ld		bc,ACKPORT						; kick the command
			out 	(c),c
			ret

			; ------------------------- fclose
			; -- parameters:
			; -- A = file fd
			; -- return
fclose:

			ld		bc,DATAPORT
			out		(c),c			; ignore first byte
			ld		de,C_CLOSE
			out		(c),e
			out		(c),d
			out		(c),a		; fd
			ld		b,ACKPORT>>8	; kick command
			out		(c),c
			
			ret





m4rom_enable:
			
			; M4 detection via C_ROMLOW command (only from FW v2.0.7 )
			
			ld		bc,DATAPORT
			out		(c),c			; ignore first byte
			ld		de,C_ROMLOW
			out		(c),e
			out		(c),d
			ld		a,2				; enable lowerrom from HACK MENU
			out		(c),a
			ld		b,ACKPORT>>8	; kick command
			out		(c),c
		
			; page in lowerrom
		
			ld		bc,0x7F89
			out		(c),c
			ld 		a,(0x100)
			cp 		0x4D					; detect 'M' from "MV - SNA" string, to determine if M4 present
			jr		z, m4_found
			ld		a, 255
			ret
m4_found:
			ld 		a,(0x0)					; get M4 rom number
			push 	af
			ld		bc,DATAPORT
			out		(c),c			; ignore first byte
			ld		de,C_ROMLOW
			out		(c),e
			out		(c),d
			xor		a				; re-enable system lowerrom
			out		(c),a
				
			ld		b,ACKPORT>>8	; kick command
			out		(c),c
		
			
			; select M4 upperrom
			
			pop 	af
			ld		bc,0xDF00
			out		(c),a
			
			; enable upperrom & disable lower
			ld		bc,0x7F85
			out		(c),c
			
			ret


m4rom_disable:
			
			; diable upperrom (and lower)
			
			ld	bc,0x7F8D
			out	(c),c
			ret


wrt:
			ld	a,(hl)
			or	a
			ret	z
			call txt_output
			inc	hl
			jr	wrt
		
txt_error:
			db "M4 Board not found !",7,0

fname:
			db "/TEST.ASC",0
buffer:		ds 32
