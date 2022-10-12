;reset and manage state of all ppu registers
;shared version 0
;(c functions are assumed __fastcall__
;unless otherwise specified)
.FEATURE c_comments
.import _main,_init
.import pushax,popax,pusha,popa

;boilerplate stuff and linker gen. symbols
;most of this is never explained bc documentation is trash
	.export   __STARTUP__ : absolute = 1 ; Mark as startup
	.import   __RAM_START__, __RAM_SIZE__

.include  "zeropage.inc"

;-MACROS-
.include "lib/utilmacros.s"

;-GLOBAL LABELS-
.include "lib/labeldef.s"

.segment "HEADER"
.include "lib/nrom_header.s"

.segment "ZEROPAGE"
.include "lib/labeldef_zp.s"

;i couldn't get OAMBuffer to just be = to 0x0200 in c
;so now these are all a #define fight me
.segment "NAMETABLE_BUF"
;.export _nametableBuffer
_nametableBuffer:   .res 160
.segment "OAM_BUF"
_OAMBuffer:         .res 256  ;OAM_Entry* (typedef struct array)
;//attributes:
;//76543210
;//||||||||
;//||||||++- Palette (4 to 7) of sprite
;//|||+++--- Unimplemented (read 0)
;//||+------ Priority (0: in front of background; 1: behind background)
;//|+------- Flip sprite horizontally
;//+-------- Flip sprite vertically
.segment "APU_BUF"
_APUBuffer:         .res 256

.segment "BSS"

.segment  "STARTUP"

.export   _reset

_reset: ;void (void)
	sei						;enable 'ignore irq?' bit
	cld						;clear decimal mode
	ldx #%01000000			;disable apu frame irq
	stx	APU_FRAME_COUNTER	;^^
	ldx #$ff				;set up stack
	txs						;^^
	inx						;x=0
	stx PPUCTRL				;disable nmi
	stx PPUMASK				;disable rendering (start fblank)
	stx APU_DMC_CONTROL		;disable dmc irqs
	bit PPUSTATUS			;init vblank flag to known state
	jsr _spin				;wait for 1st vblank
@clearMemoryLoop:			;flush ram
	lda #0					;^^
	sta $0000,x				;^^
	sta $0100,x				;^^
	;sta $0200,x			;^^(oam buffer handled separately)
	sta $0300,x				;^^
	sta $0400,x				;^^
	sta $0500,x				;^^
	sta $0600,x				;^^
	sta $0700,x				;^^
	lda #$ff				;^^#$ff for oam so that sprites start off screen
	sta _OAMBuffer,x		;^^
	inx						;^^
	bne @clearMemoryLoop	;^^
	stx	OAMADDR				;OAMADDR=0 bc i use OAMDMA instead
	lda	#<(__RAM_START__ + __RAM_SIZE__ -1)	;set cc65 argument stack pointer
	sta	sp									;^^
	lda	#>(__RAM_START__ + __RAM_SIZE__ -1)	;^^(remove -1 if things go wack)
	sta	sp+1								;^^
	lda #$aa				;seed rng
	sta _randomNuml			;^^
	sta _randomNumh			;^^
	;bit PPUSTATUS
	;init frame status
	;7=true: main loop finished
	;5=true: apply scroll value
	lda #%10100000			;see above
	sta _fstatus			;^^
	jsr _spin				;wait for 2nd vsync
	lda #%00011110			;enable sprites & background (stop fblank)
	sta _ppumask			;^^
	sta PPUMASK				;^^
	lda #%10010000			;enable nmi; patt. table: sprite=left, background=right
	sta _ppuctrl			;^^
	sta PPUCTRL				;^^
	cli						;reenable irq
	jsr _init				;jump to and return from c init
	jsr _spin				;scroll update seems to not happen
	bit PPUSTATUS			;^^properly unless i spin before it!
	lda #0					;^^
	sta PPUSCROLL			;^^timing issue i guess
	sta PPUSCROLL			;^^
	jmp	asm_main			;jump to main loop

.segment "CODE"

.export _vblank,_spin
.export _toIntS,_toIntU
.export _random8,_random16
.export _getButtons
.export _ppuScroll,_ppuAddress,_vmemprep
.export _cos,_sin

asm_main:
	lda _ppuctrl		;disable nmi
	and #%01111111		;^^
	sta _ppuctrl		;^^
	sta PPUCTRL			;^^
	lda _fstatus		;reset 'main loop finished?' flag
	and #%01111111		;^^
	sta _fstatus		;^^

	lda #0				;for zeroing out frame counters
	ldx #60				;for frame compares
	inc _fcounterTOT	;inc total frames count and/or reset
	cpx _fcounterTOT	;^^
	bne @incFCountTOT	;^^
	sta _fcounterTOT	;^^reset if 60 frames elapsed since last reset
@incFCountTOT:


	jsr _main			;jsr to c main
	
	lda _fstatus		;set 'main loop finished?' flag
	ora #%10000000		;^^
	sta _fstatus		;^^
	lda _ppuctrl		;enable nmi
	ora #%10000000		;^^
	sta _ppuctrl		;^^
	sta PPUCTRL			;^^
	jsr _spin			;wait until next vblank
	jmp asm_main

_vblank:
	lda #0				;for zeroing out frame counters
	ldx #60				;for frame compares
	bit _fstatus		;if game loop hasn't finished, exit nmi early
	bmi @doVBlank		;^^(game loop finished = bit 7 true)
	inc _fcounterLAG	;inc amount of lag frames (this can roll over lol)
	rti					;exit nmi
@doVBlank:				
	;sta _fcounterLAG	;game loop finished before nmi; reset lag frames
	inc _fcounterNLG	;inc no lag frames count and/or reset
	cpx _fcounterNLG	;^^
	bne @incFCountNLG	;^^
	sta _fcounterNLG	;^^reset if 60 frames elapsed since last reset
@incFCountNLG:
	lda _ppumask		;start fblank
	and #%11100111		;^^
	sta _ppumask		;^^
	sta PPUMASK			;^^
	
	lda _fstatus		;skip scroll update if bit 5 = false
	and #%00100000		;^^
	beq @skipScroll		;^^
	bit PPUSTATUS		;reset address latch
	lda _scrollX		;fetch scroll from zp and write to PPUSCROLL
	sta PPUSCROLL		;^^
	ldx _scrollY		;^^
	stx PPUSCROLL		;^^
	lda _fstatus		;reset 'update scroll' flag
	and #%11011111		;^^
	sta _fstatus		;^^
@skipScroll:

	;upload things to vram
	bit _fstatus
	bvc @skipPPUUpload	;if bit 6 of fstatus set, upload to vram
	lda _fstatus		;reset 'upload to vram?' flag
	and #%10111111		;^^
	sta _fstatus		;^^
	ldy #0				;init index to 0
@uploadChunk:			
	lda PPUBuffer,y		;init counter to length of chunk
	tax					;^^
	iny					;write address to PPUADDR
	bit PPUSTATUS		;^^reset address latch
	lda PPUBuffer,y		;^^
	sta PPUADDR			;^^
	iny					;^^
	lda PPUBuffer,y		;^^
	sta PPUADDR			;^^
	iny					;^^
@uploadLoop:			
	lda PPUBuffer,y		;fetch current byte of chunk
	sta PPUDATA			;upload said byte to vram
	iny					;advance index and counter by 1 byte
	dex					;^^
	bne @uploadLoop		;break chunk loop once x counts down to 0
	cpy _ppuBufferLen	;break upload loop once y = total buffer len
	bne @uploadChunk	;^^
	lda #0				;reset buffer length to 0
	sta _ppuBufferLen	;^^
@skipPPUUpload:
	lda #>_OAMBuffer	;upload OAMBuffer to actual OAM
	sta OAMDMA			;^^
	lda _ppumask		;stop fblank
	ora #%00011000		;^^
	sta _ppumask		;^^
	sta PPUMASK			;^^
_irq: ;lmao
	rti


_spin: ;void (void)
	bit PPUSTATUS	;did vblank happen? (bit 7=1)
	bpl _spin		;if not, go back
	rts

;turns fixed point number with 6 bits of fraction to int
_toIntU: ;uint16_t (uint16_t)
	ldy #3
	bpl _toIntU_start	;always branch
_toIntS: ;int16_t (int16_t)
	ldy #2
_toIntU_start:
	stx swap
	bit swap
	bpl @posNumber
	dey
@posNumber:
	lsr swap		;unrolled loop
	ror				
	lsr swap		
	ror				
	lsr swap		
	ror				
	lsr swap		
	ror				
	lsr swap		
	ror				
	lsr swap		
	ror				
	dey				
	bne @negNumber	
	tay				;bit extension if negative
	lda #%11111100	;^^
	ora swap		;^^
	sta swap		;^^
	tya				;^^
@negNumber:			
	ldx swap		
	rts				

;8-bit xorshift prng
;source: https://gist.github.com/bhickey/0de228c02cc60b5965582d2d946d8c38
_random8: ;uint8_t (void)
	lda _randomNuml
	asl
	eor _randomNuml
	sta _randomNuml
	lsr
	eor _randomNuml
	sta _randomNuml
	asl
	asl
	eor _randomNuml
	sta _randomNuml
	rts
;16-bit xorshift prng
;(gonna be honest, this routine is a black box that i
;don't fully understand)
;source: https://codebase64.org/doku.php?id=base:16bit_xorshift_random_generator
_random16: ;uint16_t (void)
	lda _randomNumh
	lsr		
	lda _randomNuml
	ror		
	eor _randomNumh
	sta _randomNumh	; high part of x ^= x << 7 done
	ror				; A has now x >> 9 and high bit comes from low byte
	eor _randomNumh	
	sta _randomNuml	; x ^= x >> 9 and the low part of x ^= x << 7 done
	eor _randomNumh	
	sta _randomNumh	; x ^= x << 8 done	
	tax				;set up __fastcall__ return
	lda _randomNuml	;^^
	rts

;most of this yoinked from nesdev iirc
;this populates joypadState 1&2 with current controller state
_getButtons: ;U_Reg16 (void)
	;set up poll
	lda #$01		 ;start refreshing controller(s) state
	sta JOYPAD1		 ;^^
	sta _joypadState2 ;player2r=1 so carry bit after 8th button read is 1
	lsr				 ;stop refreshing controller(s) state (a=0 now)
	sta JOYPAD1		 ;^^
@readLoop:
	lda JOYPAD1		 ;bit 0 from JOYPAD1 -> carry flag
	lsr				 ;^^
	rol _joypadState1 ;controller 1 read buffer <- carry flag
	lda JOYPAD2		 ;bit 0 from JOYPAD2 -> carry flag
	lsr				 ;^^
	rol _joypadState2 ;controller 2 read buffer <- carry flag
	bcc @readLoop	 ;once player1r rotates 8 times, carry = 1
	;lda _joypadState1 ;set up __fastcall__ return
	;ldx _joypadState2 ;^^(low byte=player 1; high=player 2)
	rts


_ppuScroll: ;void(uint8_t x, uint8_t y)
	sta _scrollY	;store x&y to ram
	jsr popa		;^^
	sta _scrollX	;^^
	lda _fstatus	;set 'update scroll' flag
	ora #%00100000	;^^
	sta _fstatus	;^^
	rts
	
_ppuAddress: ;void(uint16_t*)
	bit PPUSTATUS	;reset ppu address latch
	stx PPUADDR		;hi byte of address
	sta PPUADDR		;lo byte of address
	rts
;puts data in ppu buffer for rendering
;returns length of buffer post-copy (+ 3 header bytes each chunk)
;chunk header = len, dst high, dst low
_vmemprep: ;uint8_t(void* src, void* dst, uint8_t len)
	cmp #0				;skip buffer write if len=0
	bne	@doPrep			;^^
	jsr popax			;^^(pop args off just to revert
	jsr popax			;^^sp to where it was)
	lda _ppuBufferLen	;^^return current buffer length
	rts					;^^
@doPrep:				;
	tay					;unset 'upload to vram?' flag
	lda _fstatus		;^^(this is to make sure unfinished garbage data
	and #%10111111		;^^isn't written to the buffer)
	sta _fstatus		;^^
	tya					;^^
	ldy _ppuBufferLen	;load start address of chunk
	sta PPUBuffer,y		;store length of chunk at byte 0 of chunk
	iny					;^^one byte added; iny
	clc					;ppuBufferLen += 3+len
	adc #3				;^^
	clc					;^^
	adc _ppuBufferLen	;^^
	sta _ppuBufferLen	;^^
	sty r16bl			;preserve y value
	jsr popax			;pop DeSTination off parameter stack
	ldy r16bl			;restore y value
	sta swap			;store hi byte of dst at byte 1 of chunk
	txa					;^^
	sta PPUBuffer,y		;^^
	iny					;^^
	lda swap			;store lo byte of dst at byte 2 of chunk
	sta PPUBuffer,y		;^^
	iny					;^^
	sty r16bl			;preserve y value
	jsr popax			;pop SouRCe pointer off of stack
	ldy r16bl			;restore y value
	sta r16al			;store src for indirection
	stx r16ah			;^^
	tya					;use x to absolute index place in buffer;
	tax					;^^use y to indirect index place in src
	ldy #0				;^^
@loop:					;
	lda (r16al),y		;pull current byte from source
	sta PPUBuffer,x		;add said byte into buffer
	inx					;inc both by 1
	iny					;^^
	cpx _ppuBufferLen	;break loop after writing len bytes
	bne @loop			;^^
	lda _fstatus		;set 'upload to vram?' flag
	ora #%01000000		;^^
	sta _fstatus		;^^
	lda	_ppuBufferLen	;return new buffer len
	rts					


;fixed point sin/cos fastcall function (radians)
;takes unsigned 16-bit, returns signed 16 bit
;uses 6 bits of fraction
;2pi=402=110.010010
;cos(x)=sin(x-.5pi)=sin(x+1.5pi)
_cos: ;int16_t (uint16_t)
	COSADD=96	;302-256 (actually, now it's 1.75pi*64-256)
	clc			;add 302, or ~1.5pi (46+256)
	adc #COSADD	;^^(a circle seems to deform at that actually,
	bcc _sin	;^^but seems to work after adding another .25pi.)
	inx			;^^increment for high byte
_sin: ;int16_t (uint16_t)
	sta r16al   ;dividend
	stx r16ah   ;^^
	lda #<$0192 ;divisor ($192=402=146+256)
	sta r16bl   ;^^
	lda #>$0192 ;^^
	sta r16bh   ;^^
	;division code yoinked from (bc i'm too dumb to make my own):
	;https://codebase64.org/doku.php?id=base:16bit_division_16-bit_result
    ;r16a=dividend; r16b=divisor; r16c=remainder result=swap
	lda #0	    ;preset remainder to 0
	sta r16cl
	sta r16ch
	ldx #16		;repeat for each bit: ...
@divloop:
	asl r16al	;dividend lb & hb*2, msb -> Carry
	rol r16ah	
	rol r16cl	;remainder lb & hb * 2 + msb from carry
	rol r16ch
	lda r16cl
	sec
	sbc r16bl	;substract divisor to see if it fits in
	tay	        ;lb result -> Y, for we may need it later
	lda r16ch
	sbc r16bh
	bcc @skip	;if carry=0 then divisor didn't fit in yet
	sta r16ch	;else save substraction result as new remainder,
	sty r16cl	
	inc swap	;and INCrement result cause divisor fit in 1 times
@skip:
	dex
	bne @divloop
	;;
	lda r16cl				;add location of lookup table to offset
	clc						;^^
	adc #<sin_table			;^^
	sta r16cl				;^^
	lda r16ch				;^^high byte
	adc #>sin_table			;^^
	sta r16ch				;^^
	ldx #0					;init extended sign to 0
	lda (r16cl,x)			;
	bpl @no_sign_extension	;if low byte is negative, extend sign of high byte to $ff
	dex ;x=#%11111111		;^^
@no_sign_extension:			
	rts						

.segment "RODATA"

sin_table:;00  01  02  03  04  05  06  07  08  09  0A  0B  0C  0D  0E  0F
    .byte $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f ;0000
	.byte $10,$11,$12,$13,$14,$15,$16,$17,$17,$18,$19,$1a,$1b,$1c,$1d,$1e ;0010
	.byte $1f,$20,$20,$21,$22,$23,$24,$25,$25,$26,$27,$28,$29,$29,$2a,$2b ;0020
    .byte $2c,$2c,$2d,$2e,$2e,$2f,$30,$30,$31,$32,$32,$33,$34,$34,$35,$35 ;0030
	.byte $36,$36,$37,$37,$38,$38,$39,$39,$3a,$3a,$3b,$3b,$3b,$3c,$3c,$3c ;0040
	.byte $3d,$3d,$3d,$3e,$3e,$3e,$3e,$3f,$3f,$3f,$3f,$3f,$3f,$40,$40,$40 ;0050
    .byte $40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$3f,$3f,$3f ;0060
	.byte $3f,$3f,$3f,$3e,$3e,$3e,$3e,$3d,$3d,$3d,$3c,$3c,$3c,$3b,$3b,$3b ;0070
	.byte $3a,$3a,$39,$39,$38,$38,$37,$37,$36,$36,$35,$35,$34,$34,$33,$32 ;0080
    .byte $32,$31,$31,$30,$2f,$2f,$2e,$2d,$2c,$2c,$2b,$2a,$29,$29,$28,$27 ;0090
	.byte $26,$25,$25,$24,$23,$22,$21,$20,$20,$1f,$1e,$1d,$1c,$1b,$1a,$19 ;00A0
	.byte $18,$17,$17,$16,$15,$14,$13,$12,$11,$10,$0f,$0e,$0d,$0c,$0b,$0a ;00B0
    .byte $09,$08,$07,$06,$05,$04,$03,$02,$01,$00,$ff,$fe,$fd,$fc,$fb,$fa ;00C0
	.byte $f9,$f8,$f7,$f6,$f5,$f4,$f3,$f2,$f1,$f0,$ef,$ee,$ed,$ec,$eb,$ea ;00D0
	.byte $ea,$e9,$e8,$e7,$e6,$e5,$e4,$e3,$e2,$e1,$e0,$e0,$df,$de,$dd,$dc ;00E0
    .byte $db,$db,$da,$d9,$d8,$d7,$d7,$d6,$d5,$d4,$d4,$d3,$d2,$d2,$d1,$d0 ;00F0
	.byte $d0,$cf,$ce,$ce,$cd,$cc,$cc,$cb,$cb,$ca,$ca,$c9,$c9,$c8,$c8,$c7 ;0100
	.byte $c7,$c6,$c6,$c5,$c5,$c5,$c4,$c4,$c4,$c3,$c3,$c3,$c2,$c2,$c2,$c2 ;0110
    .byte $c1,$c1,$c1,$c1,$c1,$c1,$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0 ;0120
	.byte $c0,$c0,$c0,$c0,$c0,$c0,$c1,$c1,$c1,$c1,$c1,$c1,$c2,$c2,$c2,$c2 ;0130
	.byte $c3,$c3,$c3,$c4,$c4,$c4,$c5,$c5,$c5,$c6,$c6,$c7,$c7,$c8,$c8,$c9 ;0140
    .byte $c9,$ca,$ca,$cb,$cb,$cc,$cc,$cd,$ce,$ce,$cf,$cf,$d0,$d1,$d1,$d2 ;0150
	.byte $d3,$d4,$d4,$d5,$d6,$d7,$d7,$d8,$d9,$da,$da,$db,$dc,$dd,$de,$df ;0160
	.byte $df,$e0,$e1,$e2,$e3,$e4,$e5,$e6,$e7,$e8,$e8,$e9,$ea,$eb,$ec,$ed ;0170
    .byte $ee,$ef,$f0,$f1,$f2,$f3,$f4,$f5,$f6,$f7,$f8,$f9,$fa,$fb,$fc,$fd ;0180
	.byte $fe,$ff                                                         ;0190

.segment "VECTORS"
	.addr _vblank
	.addr _reset  ;program counter initializes here iirc
	.addr _irq

.segment "CHARS_A" ;left pattern table
	;0: amogus
	.byte %00111111
	.byte %00111111
	.byte %11110111
	.byte %11110000
	.byte %11111111
	.byte %11111111
	.byte %00110011
	.byte %00110011 ;
	.byte %00000000 
	.byte %00000000
	.byte %00001111
	.byte %00001111
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000 ;
	
	;1: paddle left
	.byte %01011101
	.byte %00101110
	.byte %01011101
	.byte %00101110
	.byte %01011101
	.byte %00101110
	.byte %01011101
	.byte %00101110 ;
	.byte %00000010
	.byte %00000001
	.byte %00000010
	.byte %00000001
	.byte %00000010
	.byte %00000001
	.byte %00000010
	.byte %00000001 ;
	;2: paddle right
	.byte %00010111
	.byte %10001011
	.byte %00010111
	.byte %10001011
	.byte %00010111
	.byte %10001011
	.byte %00010111
	.byte %10001011 ;
	.byte %11111111
	.byte %01111111
	.byte %11111111
	.byte %01111111
	.byte %11111111
	.byte %01111111
	.byte %11111111
	.byte %01111111 ;
	
	;stars (this could just be 1 pattern with palette swaps)
	;0/3
	.byte %00000000
	.byte %00010000
	.byte %00101000
	.byte %01010100
	.byte %00101000
	.byte %00010000
	.byte %00000000
	.byte %00000000 ;
	.byte %00010000
	.byte %01010100
	.byte %00111000
	.byte %11101110
	.byte %00111000
	.byte %01010100
	.byte %00010000
	.byte %00000000 ;
	;1/3
	.byte %00010000
	.byte %01000100
	.byte %00010000
	.byte %10101010
	.byte %00010000
	.byte %01000100
	.byte %00010000
	.byte %00000000 ;
	.byte %00010000
	.byte %01010100
	.byte %00101000
	.byte %11010110
	.byte %00101000
	.byte %01010100
	.byte %00010000
	.byte %00000000 ;
	;2/3
	.byte %00000000
	.byte %00010000
	.byte %00101000
	.byte %01010100
	.byte %00101000
	.byte %00010000
	.byte %00000000
	.byte %00000000 ;
	.byte %00010000
	.byte %01000100
	.byte %00010000
	.byte %10111010
	.byte %00010000
	.byte %01000100
	.byte %00010000
	.byte %00000000 ;
	;3/3
	.byte %00010000
	.byte %01000100
	.byte %00010000
	.byte %10101010
	.byte %00010000
	.byte %01000100
	.byte %00010000
	.byte %00000000 ;
	.byte %00000000
	.byte %00010000
	.byte %00111000
	.byte %01111100
	.byte %00111000
	.byte %00010000
	.byte %00000000
	.byte %00000000 ;

.segment "CHARS_B" ;right pattern table
	
	
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte %10000001
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte %10000001
	

.include "text8x8.inc"

.segment "DATA"