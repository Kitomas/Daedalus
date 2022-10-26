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

;sincos

.segment "RODATA"

.segment "VECTORS"
	.addr _vblank
	.addr _reset
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