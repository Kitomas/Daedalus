.ifndef L_SINCOS6_S
.define L_SINCOS6_S=1

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
	
.endif