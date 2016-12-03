			; AMSDOS fast copy using
			; cas in/out char, with ptr manipulation
			; tested with regular AMSDOS and M4 rom
			; Duke 2016

			org &4000
			nolist
			
			ld	b,10
			ld	hl,filename
			ld	de,inbuffer
			
			call &bc77 		; CAS IN OPEN
			push	bc
			
			push	hl
			ld	de,header		
			ld	bc,128
			ldir				; save it for later
			pop	hl
			ld	de,-5
			add	hl,de
			ld	(fileheadin),hl
			
			pop	hl
			ld	(filesize),hl
		
			push	af			; filetype
			
			ld	b,10
			ld	hl,filename2
			ld	de,outbuffer
			call	&bc8c		; CAS OUT OPEN
			ld	de,-5
			add	hl,de
			ld (fileheadout),hl
			
			pop	af
		
			; check if filetype has header or not
			; skipped for now, assume it does
			
			call	&bc80		; fill 2k buffer
			
			ld	hl,header
			ld	a,(hl)
			call &BC95
			ld	de,outbuffer
			ld	bc,128
			ldir
			ld	hl,inbuffer
			ld	bc,2048-128
			ldir
		
			; check if remains of file is less than 2k - 128
			ld	hl,(filesize)
			ld	de,128
			add	hl,de
			ld	bc,&F800			; -&800
			push	hl
			add	hl,bc				; and substract chunksize
			pop	de
			jr	c, full_chunk
			ld	c,e
			ld	b,d
			jr	cont1
			
full_chunk:	ld	bc,&800
			jr	cont1

cont1:		ld	(filesize),hl
						
			; increase ptr to write out 2k buffer (or filesize) at once
			
			ld	iy,(fileheadout)
			ld	(iy),1
			
			ld	l,(iy+1)		; get buffer
			ld	h,(iy+2)
			add	hl,bc
			ld	(iy+3),l		; current pos is end of buffer
			ld	(iy+4),h
			ld	(iy+24),c		; size is 2k too
			ld	(iy+25),b
			; write 2k block
			call &bc95
			ld	a,8
			cp	b			; was it 2k
			jp	nz, copy_done
			
			; copy remaining bytes of input buffer to output buffer
copy_loop:		
			ld	hl,inbuffer+2048-128
			ld	de,outbuffer
			ld	bc,128
			ldir
			ld	iy,(fileheadin)
			
			ld	hl,(filesize)
			ld	bc,&F800			; -&800
			push	hl
			add	hl,bc			; and substract chunksize
			pop	de
			jr	c, full_chunk1
			ld	c,e
			ld	b,d
			jr	cont2
			
full_chunk1:	ld	bc,&800

		
			; re-fill input buffer
		
cont2:		ld	(filesize),hl
			
			ld	l,(iy+1)		
			ld	h,(iy+2)
			
			add	hl,bc
			ld	(iy+3),l		; adjust current pos to end of buffer
			ld	(iy+4),h
			ld	(iy+&18),0	; clear buffer remains
			ld	(iy+&19),0
			call	&bc80		; fill 2k buffer
			push	bc
			ld	hl,inbuffer
			ld	de,outbuffer+128
			ld	bc,2048-128
			ldir
			pop	bc
			
			; write 2k buf
			ld	iy,(fileheadout)
			ld	(iy),1
			
			ld	l,(iy+1)		; get buffer
			ld	h,(iy+2)
			add	hl,bc
			ld	(iy+3),l		; current pos is end of buffer
			ld	(iy+4),h
			ld	(iy+24),c		; size is 2k too
			ld	(iy+25),b
			
			call &bc95
		
			ld	a,8
			cp	b			; was it 2k
			jr	z,copy_loop
			ld	l,(iy+3)		; get buffer
			ld	h,(iy+4)
			dec	hl			; get rid of extra char
			ld	(iy+3),l		
			ld	(iy+4),h		 
			
			
copy_done:			
			call &bc7a
			call &bc8f
			ret
			
		

fileheadin:	dw	0
fileheadout:	dw	0
filesize:		dw	0
filename: 	db	"filein.bin"
filename2: 	db	"fileot.bin"
header: 		ds	128
inbuffer:		ds	2048
outbuffer:	ds	2048