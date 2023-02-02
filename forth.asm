; ************************************************************************************************
; 6502 WIP for Foenix256Jr.
;  
; ************************************************************************************************
 
			.cpu    "65c02"

; use kernel API and KEYS includes
; from https://github.com/ghackwrench/F256_Jr_Kernel_DOS
	
			.include    "kernel/api.asm"
			.include    "kernel/keys.asm"
		
MMU_MEM_CTRL 	= $0000
MMU_IO_CTRL 	= $0001
VKY_MSTR_CTRL_0 = $D000
VKY_MSTR_CTRL_1 = $D001			
TEXT_LUT_FG 	= $d800
TEXT_LUT_BG 	= $d840

MAX_LINE 		= 60
 
; memory layout
; small parameter stack for expressions
; small locals stack for local zero page reuse.
; return stack for high level words, if we have any.

; subroutine nesting limit is 64 deep (with locals)
PBASE	=	$5f00 	; 256 byte parameter stack - grows up from 23296
LBASE	=	$5b00	; 1024 = 64 x 16byte locals frames - grows up
RBASE	=	$5a00	; 256 byte return stack - grows up from 23040


; define memory layout see DOS example from link above.

            .virtual    $0000   ; Zero page
mmu_ctrl    .byte       ?
io_ctrl     .byte       ?
reserved    .fill       6
mmu         .fill       8
            .dsection   dp
			.cerror * > $00ff, "Out of dp space."
            .endv
 
; page zero variables.

			.section    dp
	
; shared/global zero page	
screen  .word   ?	; screen position
from	.word 	?	; for copying
to		.word 	?	; for copying
status	.word	? 	; track keyboard status
curx	.byte	?	; cursor
cury	.byte 	?	; cursor

W		.word 	?    
I 		.word   ?	 
L 		.word   ?	 ; locals stack ptr
D 		.word   ?
E 		.word   ?	 
R  		.word   ?	 
P     	.byte   ?	 ; parameter stack	
U		.word 	?	 
B		.word	?	
C 		.word	?
K   	.word   ?	; keys and chars
N   	.word   ?	; numbers

; reused zero page - backed up to stack
; locals and self 
la		.word	?
lb		.word	?
lc		.word 	?
ld		.word	?
lx 		.word	?
ly 		.word	?
lz		.word	?
self	.word	?



			.endsection	

	* = $2000
	bra 	Start 							 
	.text 	"BT65" 			; tell basic we are runnable machine code
										 

Start
	jmp		Begin


		
; interpreter guts		-------------------------------------------------------------------

Init	
		; reset P stack to 24320 5f00
		lda		#<PBASE	
		sta		P+0
		lda		#>PBASE	
		sta		P+1

		; reset L stack 
		lda		#<LBASE	
		sta		L+0
		lda		#>LBASE	
		sta		L+1
		
		; reset R stack 
		lda		#<RBASE	
		sta		R+0
		lda		#>RBASE	
		sta		R+1
		
		rts

; on entry to a word, save the callers zero page locals.
savelocals	
		ldy		#0
		lda		la 
		sta		(L),y 
		iny
		lda		la+1 
		sta		(L),y 
		iny
		lda		lb
		sta		(L),y 
		iny
		lda		lb+1
		sta		(L),y 
		iny
		lda		lc
		sta		(L),y 
		iny
		lda		lc+1
		sta		(L),y 
		iny
		lda		ld
		sta		(L),y 
		iny
		lda		ld+1
		sta		(L),y 
		iny
		lda		lx
		sta		(L),y 
		iny
		lda		lx+1
		sta		(L),y 
		iny
		lda		ly
		sta		(L),y 
		iny
		lda		ly+1
		sta		(L),y 
		iny
		lda		lz
		sta		(L),y 
		iny
		lda		lz+1
		sta		(L),y 
		iny
		lda		self
		sta		(L),y 
		iny
		lda		self+1
		sta		(L),y 
		iny
		
		tya		
		clc
		adc		L 
		bcc 	_exit
		inc		L
_exit		
		rts
		
; on exit from a word restore callers locals		
restorelocals		
	
		ldy		#0
		lda		(L),y
		sta		la 
		iny 
		lda		(L),y
		sta		la+1 
		iny 
		
		lda		(L),y
		sta		lb 
		iny 
		lda		(L),y
		sta		lb+1 
		iny 
		
		lda		(L),y
		sta		lc
		iny 
		lda		(L),y
		sta		lc+1 
		iny 
		
		lda		(L),y
		sta		ld
		iny 
		lda		(L),y
		sta		ld+1 
		iny 
		
		lda		(L),y
		sta		lx
		iny 
		lda		(L),y
		sta		lx+1 
		iny 
		
		lda		(L),y
		sta		ly
		iny 
		lda		(L),y
		sta		ly+1 
		iny 
		
		lda		(L),y
		sta		lz
		iny 
		lda		(L),y
		sta		lz+1 
		iny 
		
		lda		(L),y
		sta		self
		iny 
		lda		(L),y
		sta		self+1 
		iny 
		
		tya		
		sec
		sbc		L 
		bcc 	_exit
		dec		L
		
_exit		

rts	
		
		
		
; screen editor related -----------------------------------------------------------------		
; screen=$C000 +(y*80)+x  		
calcscreenpos

		stz		io_ctrl
		lda		cury
		sta		$DE00
		stz		$DE01
		lda		#80
		sta		$DE02
		stz		$DE03
		lda     #$C0
		clc
		adc		$DE05
        sta     screen+1
		lda		#0
        adc     $DE04
		sta     screen+0
		
		clc
		lda		screen+0
		adc		curx
		sta 	screen+0
		bcc		_nocarry			
		inc		screen+1
_nocarry	
		lda		screen+0
		rts
		
deletefowards

		jsr		calcscreenpos
		
		sta		from+0
		sta		to+0
		lda		screen+1
		sta		from+1
		sta		to+1
		
		lda		to+0
		adc		#1
		sta 	to+0
		bcc		_skip			
		inc		to+1
_skip
	
		lda     #2
        sta     io_ctrl
		clc

		ldy 	#0
		lda		#80
		sbc		curx
		tax

        beq 	_exit
		
_loop   lda 	(to),y  
        sta 	(from),y
        iny
        dex
        bne 	_loop
		
		lda		#' '		
		sta 	(from),y
		
_exit		
		stz		K
		stz		io_ctrl
		rts

deletebackwards

		jsr		calcscreenpos
		
		sta		from+0
		sta		to+0
		lda		screen+1
		sta		from+1
		sta		to+1
		
		lda		to+0
		adc		#1
		sta 	to+0
		bcc		_skip			
		inc		to+1
_skip
	
		lda     #2
        sta     io_ctrl
		clc

		ldy 	#0
		lda		#80
		sbc		curx
		tax

        beq 	_exit
		
_loop   lda 	(to),y  
        sta 	(from),y
        iny
        dex
        bne 	_loop
		
		lda		#' '		
		sta 	(from),y
		
_exit	
		
		lda 	#0
		cmp		curx 
		bcs		_exit_left
		dec		curx 
	 
		
_exit_left

		jsr 	cursor_at
		
		stz		K
		stz		io_ctrl
		rts


	
cursortoscreen

		jsr		calcscreenpos
		
		sta		from+0
		sta		to+0
		lda		screen+1
		sta		from+1
		sta		to+1
		
		clc
		lda		to+0
		adc		#1
		sta 	to+0
		bcc		_skip			
		inc		to+1
_skip
	
		lda     #2
        sta     io_ctrl
		clc

 
		lda		#80
		sbc		curx
		tay

        beq 	_exit	
		 
_loop   
		lda 	(from),y  
        sta 	(to),y
        dey
        bpl 	_loop
		
		lda		K
		bne		_store
		lda		#32
_store
		sta 	(screen)
	
		
_exit		
		stz		K
		stz		io_ctrl
		rts

 
 
Begin	
		; clear flag for basic to start normally after the next reset 
		stz 	$2002		
		stz 	$2003		
		stz 	$2004
		stz 	$2005
		
		jsr		Init
		
		lda		#1
		sta		cury
		lda		#0
		sta		curx
		
		stz		K
 
		; tell the kernel where to send events
		lda 	#<event		
		sta 	kernel.args.events+0
		lda 	#>event
		sta 	kernel.args.events+1
	
		
		; cls, home, text mode to start
		jsr		Cls
		jsr		Home
		jsr		cursor_home
		 
	 	stz		status
		
		
		jsr 	testit
	 
		
		
		

Keyboard_loop

		stz		K

		jsr		kernel.Yield        
		jsr		kernel.NextEvent
		bcs 	Keyboard_loop
		lda 	event.type
		cmp 	#kernel.event.key.PRESSED
		beq 	_kp
		
		lda 	event.type
		cmp 	#kernel.event.key.RELEASED
		gne		Keyboard_loop
 
		; if meta key released clear status
		lda		#$80
		cmp		event.key.flags
		bne		Keyboard_loop
		
		stz		status
		stz		status+1
		
		gra 	Keyboard_loop

_kp		
		
		jsr		prnkey
 
		; if meta key pressed store key in status
		lda		#$80
		cmp		event.key.flags
		bne		_not_meta
	
		lda		event.key.raw 
		sta		status
		lda		event.key.flags
		sta		status+1

_not_meta
		lda		#32  
		cmp		event.key.ascii
		beq		_echo_bounce

		lda		event.key.ascii
		jsr		iscntrl
		bcs		_handle_control_keys
		jsr		isalpha
		bcs		_echo_bounce
		jsr		isdigit
		bcs		_echo_bounce
		jsr		ispunct
		bcs		_echo_bounce

	
		
 
_handle_control_keys

_check_right_arrow	
		lda		#6
		cmp		event.key.ascii
		bne		_check_left_arrow
		jsr		on_right_arrow
		gra		Keyboard_loop

_check_left_arrow	
		lda		#2
		cmp		event.key.ascii
		bne		_check_control_c
		jsr		on_left_arrow
		gra		Keyboard_loop
		
		
_check_control_c		
		lda		#3	; control c
		cmp		event.key.ascii	
		bne		_skip_reset_jr
		jsr		reset_jr
		
		
_skip_reset_jr

		lda		#5
		cmp		event.key.ascii
		beq		_end_key
		
		lda		#12
		cmp		event.key.ascii
		beq		_clear_screen	
		
		lda		#13
		cmp		event.key.ascii
		bne		_check_down_arrow
		jsr		crlf
		gra		Keyboard_loop
	
_check_down_arrow	
		lda		#$E
		cmp		event.key.ascii
		bne		_check_up_arrow
		jsr		on_down_arrow
		gra		Keyboard_loop
		
_check_up_arrow			
		lda		#16
		cmp		event.key.ascii
		bne		_check_delete_forward
		jsr		on_up_arrow
		gra		Keyboard_loop
		
_check_delete_forward
		
		lda		#4
		cmp		event.key.ascii
		beq		_delete_forward
		
		lda		#8
		cmp		event.key.ascii
		beq		_backspace
		
		gra		Keyboard_loop


_echo_bounce
		bra		_do_echo
		
_clear_screen
		jsr		Cls
		jsr 	Home
		jsr		cursor_home
		gra		Keyboard_loop

 
		
		
_down_arrow
		inc		cury
		jsr 	move_cursor
		gra		Keyboard_loop
			
_end_key 
		lda		#79
		sta		curx
		jsr 	cursor_at
		gra		Keyboard_loop
		
_begin_key 
		lda		#0
		sta		curx
		jsr 	cursor_at
		gra		Keyboard_loop	
		
	

_delete_forward
		jsr		deletefowards
		gra		Keyboard_loop

_backspace 
		
		jsr 	deletebackwards	
		gra		Keyboard_loop
 
	
_do_echo

		lda		event.key.ascii
		sta		K
		jsr 	cursortoscreen
		inc		curx
		jsr		move_cursor

		gra		Keyboard_loop
		
_no_echo
 
		gra		Keyboard_loop
		
			
; subroutines

on_left_arrow
		lda		status
		beq		_la_skip_flag
		lda		#0
		sta		curx
		jsr 	cursor_at
		rts	
_la_skip_flag
		lda 	#0
		cmp		curx 
		bcs		_exit_left
		dec		curx 
_exit_left
		jsr 	cursor_at
		rts

on_right_arrow

		lda		status
		beq		_ra_skip_flag
		lda		#79
		sta		curx
		jsr 	cursor_at
		rts
		
_ra_skip_flag
		lda 	#79
		cmp		curx 
		bcc		_exit_right
		inc		curx 
		
_exit_right
		jsr 	cursor_at
		rts


on_up_arrow

		lda		status
		beq		_skip 
		lda		#1
		sta		cury
		bra		_exit
_skip 
		lda 	#1
		cmp		cury
		bcs		_exit 
		dec		cury
_exit
		jsr 	cursor_at
		rts


on_down_arrow

		lda		status
		beq		_skip 
		lda		#58
		sta		cury
		bra		_exit
_skip 
		lda 	#57
		cmp		cury
		bcc		_exit 
		inc		cury
_exit
		jsr 	cursor_at
		rts





reset_jr

		stz     $1
        stz     $d010
		
		; set text mode
		lda 	#$01
		sta 	VKY_MSTR_CTRL_0
		stz 	VKY_MSTR_CTRL_1
		
	
 						 
		; do software reset
 
		lda 	#$DE
		sta 	$D6A2
		lda 	#$AD
		sta 	$D6A3
		lda 	#$80
		sta 	$D6A0
	
		rts		


Home

		lda		#1
		sta		cury
		lda		#0
		sta		curx
		jsr		cursortoscreen		 
		rts;

Cls
		; this clears text, then colour
		
		; set io page and text screen base address		
		lda     #2
        sta     io_ctrl

        stz     screen+0
        lda     #$c0
        sta     screen+1
		lda     #$20
		jsr 	screen_fill
		
		stz 	$0001 ; Switch in I/O Page #0
		
		stz 	$D810 ; Set foreground #4 to medium yellow
		lda 	#$f0
		sta 	$D811
		sta 	$D812
		
		lda 	#$AF ; Set background #5 to blue
		sta 	$D854
		lda 	#$F0
		stz 	$D855
		stz 	$D856
		
		lda 	#$03 ; Switch to I/O page #3 (color matrix)	
		sta 	$0001
	
		ldy		#80
		lda		#0
        sta     screen+0
        lda     #$c0
        sta     screen+1
		lda 	#$45 ; 
_loop
		sta		(screen),y
		dey
		bpl		_loop
		 
		; d270 last line 
		 
		ldy		#80
		lda		#$70
        sta     screen+0
        lda     #$d2
        sta     screen+1
		lda 	#$45 ; 
_loop2
		sta		(screen),y
		dey
		bpl		_loop2		 
		 
		 ; io page and text screen base address
		lda     #3
        sta     io_ctrl
	 	lda     #80
        sta     screen+0
        lda     #$c0
        sta     screen+1
		lda     #$1
		jsr     screen_fill 
		 
		
		stz		io_ctrl
		rts
		
screen_fill   
	
        ldy     #0
_y      ldx     #0
_x      sta     (screen)
        inc     screen
        bne     _next
        inc     screen+1
_next
        inx
        cpx     #80
        bne     _x
        iny
        cpy     #MAX_LINE-2
        bne     _y
        rts
 
 
crlf	
		inc		cury
		stz		curx
		jsr 	move_cursor
		rts 
 
 
cursor_home
		stz 	1 							 
		lda 	#1+4 						; enable cursor
		sta 	$D010
		lda 	#214
		sta 	$D012
		
		 
cursor_at
		stz		1
		lda 	curx
		sta 	$D014 						 
		stz 	$D015
		lda 	cury
		sta 	$D016
		stz 	$D017
		rts
		
move_cursor
		lda		#79
		cmp		curx 
		bcs		_xskip	
		inc		cury 
		lda		#0
		sta		curx
_xskip		
		lda		#58
		cmp		cury
		bcs		_yskip
		lda		#58
		sta		cury 
_yskip		
		lda		#0
		cmp		cury
		bcc		_yskip2
		lda		#1
		sta		cury
_yskip2
		
		bra		cursor_at	
 
; displays ascii, flags, raw, status on status line
prnkey
		lda     #2
        sta     io_ctrl
		
		lda		#$70
        sta     screen+0
        lda     #$d2
        sta     screen+1
		lda 	#$45 ; 
 
		lda		event.key.ascii
		sed         
		tax        
		and 	#$0F    
		cmp 	#9+1    
		adc 	#$30    
		tay         
		txa        	
		lsr  	a      	
		lsr 	a       
		lsr 	a      
		lsr 	a       
		cmp 	#9+1    
		adc 	#$30    
		cld     
		sta		(screen)
		tya		
		ldy		#1
		sta		(screen),y

		lda		#$74
        sta     screen+0

		lda		event.key.flags
		sed         
		tax        
		and 	#$0F    
		cmp 	#9+1    
		adc 	#$30    
		tay         
		txa        	
		lsr  	a      	
		lsr 	a       
		lsr 	a      
		lsr 	a       
		cmp 	#9+1    
		adc 	#$30    
		cld     
		sta		(screen)
		tya		
		ldy		#1
		sta		(screen),y

		lda		#$78
        sta     screen+0

		lda		event.key.raw
		sed         
		tax        
		and 	#$0F    
		cmp 	#9+1    
		adc 	#$30    
		tay         
		txa        	
		lsr  	a      	
		lsr 	a       
		lsr 	a      
		lsr 	a       
		cmp 	#9+1    
		adc 	#$30    
		cld     
		sta		(screen)
		tya		
		ldy		#1
		sta		(screen),y

		lda		#$7B
        sta     screen+0

		lda		status
		sed         
		tax        
		and 	#$0F    
		cmp 	#9+1    
		adc 	#$30    
		tay         
		txa        	
		lsr  	a      	
		lsr 	a       
		lsr 	a      
		lsr 	a       
		cmp 	#9+1    
		adc 	#$30    
		cld     
		sta		(screen)
		tya		
		ldy		#1
		sta		(screen),y


		stz		io_ctrl
		rts
 
 
 
 
 ; CTABLE


key_shft	= $00
key_shftr	= $01
key_ctl		= $02
key_ctlr	= $03
key_meta	= $06
key_alt		= $04
key_altr	= $05
key_caps	= $08
key_insert  = $B5
key_pause	= $B0
key_F1		= $81
key_F2		= $82
key_F3		= $83
key_F4		= $84
key_F5		= $85
key_F6		= $86
key_F7		= $87
key_F8		= $88
key_F9		= $89
key_F10		= $8A
key_F11		= $8B
key_F12		= $8C


 
char_ctl	= $80
char_prn	= $40
char_wsp	= $20
char_pct	= $10
char_upr	= $08
char_lwr	= $04
char_dgt	= $02
char_hex	= $01
	

; char_test if the character in a is a control character
iscntrl	
		tax
		lda 	#char_ctl
		bne 	char_test

; char_test if the character in a is printable
isprint	
		tax
		lda 	#char_prn
		bne 	char_test

; char_test if the character in a is punctation
ispunct	
		tax
		lda 	#char_pct
		bne 	char_test

; char_test if the character in a is upper case
isupper	
		tax
		lda	 	#char_upr
		bne 	char_test

; char_test if the character in a is lower case
islower	
		tax
		lda #char_lwr
		bne char_test

; char_test if the character in a is a letter
isalpha	
		tax
		lda #char_upr|char_lwr
		bne char_test

; char_test if the character in a is a decimal digit
isdigit	
		tax
		lda #char_dgt
		bne char_test

; char_test if the character in a is a hexadecimal digit
isxdigit 
		tax
		lda #char_hex
		bne char_test

; char_test if the character in a is letter or a digit
isalnum	
		tax
		lda #char_dgt|char_upr|char_lwr

; tests for the required bits in the look up table value
char_test	
		and ctype,x  
		beq char_fail

; set the carry flag if any target bits were found
char_pass	
		txa
		sec
		rts

; char_test if the character in a is in the ascii range $00-$7f
isascii	
		tax
		bpl char_pass

; clear the carry flag if no target bits were found
char_fail	
		txa
		clc
		rts

; if a contains a lower case letter convert it to upper case
toupper	
		jsr islower
		bcc *+4
		and #$df
		rts

; if a contains an upper case letter convert it to lower case
tolower	
		jsr isupper
		bcc *+4
		ora #$20
		rts
 

 
ctype
	.byte  char_ctl					; nul
	.byte  char_ctl					; soh
	.byte  char_ctl					; stx
	.byte  char_ctl					; etx
	.byte  char_ctl					; eot
	.byte  char_ctl					; enq
	.byte  char_ctl					; ack
	.byte  char_ctl					; bel
	.byte  char_ctl					; bs
	.byte  char_ctl|char_wsp		; tab
	.byte  char_ctl|char_wsp		; lf
	.byte  char_ctl|char_wsp		; vt
	.byte  char_ctl|char_wsp		; ff
	.byte  char_ctl|char_wsp		; cr
	.byte  char_ctl					; so
	.byte  char_ctl					; si
	.byte  char_ctl					; dle
	.byte  char_ctl					; dc1
	.byte  char_ctl					; dc2
	.byte  char_ctl					; dc3
	.byte  char_ctl					; dc4
	.byte  char_ctl					; nak
	.byte  char_ctl					; syn
	.byte  char_ctl					; etb
	.byte  char_ctl					; can
	.byte  char_ctl					; em
	.byte  char_ctl					; sub
	.byte  char_ctl					; esc
	.byte  char_ctl					; fs
	.byte  char_ctl					; gs
	.byte  char_ctl					; rs
	.byte  char_ctl					; us
	.byte  char_prn|char_wsp		; space
	.byte  char_prn|char_pct		; !
	.byte  char_prn|char_pct		; &quot;
	.byte  char_prn|char_pct		; #
	.byte  char_prn|char_pct		; $
	.byte  char_prn|char_pct		; %
	.byte  char_prn|char_pct		; &amp;
	.byte  char_prn|char_pct		; '
	.byte  char_prn|char_pct		; (
	.byte  char_prn|char_pct		; )
	.byte  char_prn|char_pct		; *
	.byte  char_prn|char_pct		; +
	.byte  char_prn|char_pct		; ,
	.byte  char_prn|char_pct		; -
	.byte  char_prn|char_pct		; .
	.byte  char_prn|char_pct		; /
	.byte  char_prn|char_dgt|char_hex	; 0
	.byte  char_prn|char_dgt|char_hex	; 1
	.byte  char_prn|char_dgt|char_hex	; 2
	.byte  char_prn|char_dgt|char_hex	; 3
	.byte  char_prn|char_dgt|char_hex	; 4
	.byte  char_prn|char_dgt|char_hex	; 5
	.byte  char_prn|char_dgt|char_hex	; 6
	.byte  char_prn|char_dgt|char_hex	; 7
	.byte  char_prn|char_dgt|char_hex	; 8
	.byte  char_prn|char_dgt|char_hex	; 9
	.byte  char_prn|char_pct		; :
	.byte  char_prn|char_pct		; ;
	.byte  char_prn|char_pct		; &lt;
	.byte  char_prn|char_pct		; =
	.byte  char_prn|char_pct		; &gt;
	.byte  char_prn|char_pct		; ?
	.byte  char_prn|char_pct		; @
	.byte  char_prn|char_upr|char_hex	; a
	.byte  char_prn|char_upr|char_hex	; b
	.byte  char_prn|char_upr|char_hex	; c
	.byte  char_prn|char_upr|char_hex	; d
	.byte  char_prn|char_upr|char_hex	; e
	.byte  char_prn|char_upr|char_hex	; f
	.byte  char_prn|char_upr		; g
	.byte  char_prn|char_upr		; h
	.byte  char_prn|char_upr		; i
	.byte  char_prn|char_upr		; j
	.byte  char_prn|char_upr		; k
	.byte  char_prn|char_upr		; l
	.byte  char_prn|char_upr		; m
	.byte  char_prn|char_upr		; n
	.byte  char_prn|char_upr		; o
	.byte  char_prn|char_upr		; p
	.byte  char_prn|char_upr		; q
	.byte  char_prn|char_upr		; r
	.byte  char_prn|char_upr		; s
	.byte  char_prn|char_upr		; t
	.byte  char_prn|char_upr		; u
	.byte  char_prn|char_upr		; v
	.byte  char_prn|char_upr		; w
	.byte  char_prn|char_upr		; x
	.byte  char_prn|char_upr		; y
	.byte  char_prn|char_upr		; z
	.byte  char_prn|char_pct		; [
	.byte  char_prn|char_pct		; \
	.byte  char_prn|char_pct		; ]
	.byte  char_prn|char_pct		; ^
	.byte  char_prn|char_pct		; char
	.byte  char_prn|char_pct		; `
	.byte  char_prn|char_lwr|char_hex	; a
	.byte  char_prn|char_lwr|char_hex	; b
	.byte  char_prn|char_lwr|char_hex	; c
	.byte  char_prn|char_lwr|char_hex	; d
	.byte  char_prn|char_lwr|char_hex	; e
	.byte  char_prn|char_lwr|char_hex	; f
	.byte  char_prn|char_lwr		; g
	.byte  char_prn|char_lwr		; h
	.byte  char_prn|char_lwr		; i
	.byte  char_prn|char_lwr		; j
	.byte  char_prn|char_lwr		; k
	.byte  char_prn|char_lwr		; l
	.byte  char_prn|char_lwr		; m
	.byte  char_prn|char_lwr		; n
	.byte  char_prn|char_lwr		; o
	.byte  char_prn|char_lwr		; p
	.byte  char_prn|char_lwr		; q
	.byte  char_prn|char_lwr		; r
	.byte  char_prn|char_lwr		; s
	.byte  char_prn|char_lwr		; t
	.byte  char_prn|char_lwr		; u
	.byte  char_prn|char_lwr		; v
	.byte  char_prn|char_lwr		; w
	.byte  char_prn|char_lwr		; x
	.byte  char_prn|char_lwr		; y
	.byte  char_prn|char_lwr		; z
	.byte  char_prn|char_pct		; {
	.byte  char_prn|char_pct		; |
	.byte  char_prn|char_pct		; }
	.byte  char_prn|char_pct		; ~
	.byte  char_ctl		; del	
	
 
 
; the kernel kindly converts interrupts into nice events.      
event	.dstruct    kernel.event.event_t   
     
	
sptr	.word		$C000	
ll		.byte		81

 

; display char in K and move text cursor.
putcharK	
		jsr 	cursortoscreen
		inc		curx
		jsr		move_cursor
		rts 


printB

		lda		B+0
		beq		_iszero 
		bra		_start
_iszero		
		lda		B+1
		bne		_start 
		
		lda		#'0'
		sta		K 
		jsr 	putcharK
		rts

_start	
		stz		_pad
		ldy 	#8                                  
_loop1
		ldx 	#$ff
		sec                              
_loop2
		lda 	B+0
		sbc 	_tens+0,y
		sta 	B+0   
		lda 	B+1
		sbc 	_tens+1,y
		sta 	B+1
		inx
		bcs 	_loop2                       
		lda 	B+0
		adc 	_tens+0,y
		sta 	B+0  
		lda 	B+1
		adc 	_tens+1,y
		sta 	B+1
		txa
		bne 	_digit                  
		lda 	_pad
		bne 	_skip1
		beq 	_next 
_digit
		ldx 	#'0'
		stx 	_pad                      
		ora 	#'0'                               
_skip1
		phx
		phy
		sta		K
		jsr 	putcharK
		ply
		plx
_next
		dey
		dey
		bpl 	_loop1                  
		rts

_pad
		.byte 	1
_tens
		.word	1,10,100,1000,10000


primitives

; remove 16 bit value from top of stack (P) into B
; print it as a decimal.

; *10 as * 2 * 2 + itself * 2
dotimes10
		ldx		P 
		lda   	PBASE+1,x         
		pha                
		lda   	PBASE+0,x     
		pha		
		jsr   	x2it          
		jsr   	x2it     
		pla
		adc   	PBASE+0,x         
		sta  	PBASE+0,x          
		pla              
		adc   	PBASE+1,x          
		sta   	PBASE+1,x          
		gra		x2it
		
dotimes2
		ldx		P 
x2it		
		asl		PBASE,x
		lda		#0
		rol		PBASE+1,x
 
		rts

dodot
		ldy		P 
		lda		PBASE,y
		sta		B+0
		lda		PBASE+1,y
		sta		B+1
		dey 
		dey 
		sty		P
		gra		printB
		
doemit
		ldy		P 
		lda		PBASE,y
		sta		K+0
		dey 
		dey 
		sty		P
		gra		putcharK
	
dozero 
		ldy		P 
		iny 
		iny
		lda		#0
		sta		PBASE,y
		lda		#0
		sta		PBASE+1,y 
		sty		P 
		rts	
		
doone 
		ldy		P 
		iny 
		iny
		lda		#1
		sta		PBASE,y
		lda		#0
		sta		PBASE+1,y 
		sty		P 
		rts

dotwo 
		ldy		P 
		iny 
		iny
		lda		#2
		sta		PBASE,y
		lda		#0
		sta		PBASE+1,y 
		sty		P 
		rts

doplus 
		ldy		P 
		dey 
		dey 
		sty		P
		clc
		
		lda		PBASE+0,y
		adc		PBASE+2,y
		sta		PBASE+0,y
		lda		PBASE+1,y
		adc		PBASE+3,y
		sta		PBASE+1,y
		rts
		
dosub 
		ldy		P 
		dey 
		dey 
		sty		P
		
		sec
		
		lda		PBASE+0,y
		sbc		PBASE+2,y
		sta		PBASE+0,y
		lda		PBASE+1,y
		sbc		PBASE+3,y
		sta		PBASE+1,y
		rts


; testit
testit
		jsr		dotwo
		jsr		dotimes10
		jsr 	dodot
 
		 
		 
		rts 



; very provisional.

dictionary

	.byte	1
	.text	'.'
	jmp		dodot
	
	.byte	1
	.text	'0'
	jmp		dozero
	
	.byte	1
	.text	'1'
	jmp		doone
	
	.byte	1
	.text	'2'
	jmp		dotwo
	
	
	
	.byte	0
	.byte	0	
	.byte	0
	.byte	0














 
; See these references for everything here
; https://github.com/daniel5151/ANESE/blob/master/research/obelisk.me.uk/6502/algorithms.html
; https://github.com/pweingar/C256jrManual/blob/main/tex/f256jr_ref.pdf
; https://tass64.sourceforge.net/
; https://github.com/ghackwrench/F256_Jr_Kernel_DOS
; https://github.com/pweingar/C256jrManual/blob/main/tex/f256jr_ref.pdf
; https://github.com/paulscottrobson/superbasic
; http://www.6502.org
; http://forum.6502.org/viewtopic.php?f=2&t=5794&view=next