.ifndef L_UTILMACROS_S
L_UTILMACROS_S=1

;increment 16-bit value
.macro inc16 address
	.local skip
	inc address
	bne skip
	inc address + 1
skip:
.endmacro
;decrement 16-bit value
.macro dec16 address
	.local skip
	dec address
	bne skip
	dec address+1
skip:
.endmacro


;far branches
  ;carry flag
.macro bcc_far address
	bcs * + 5
	jmp address
.endmacro
.macro bcs_far address
	bcc * + 5
	jmp address
.endmacro

  ;zero flag
.macro beq_far address
	bne * + 5
	jmp address
.endmacro
.macro bne_far address
	beq * + 5
	jmp address
.endmacro

  ;negative flag
.macro bmi_far address
	bpl * + 5
	jmp address
.endmacro
.macro bpl_far address
	bmi * + 5
	jmp address
.endmacro

  ;overflow flag
.macro bvc_far address
	bvs * + 5
	jmp address
.endmacro
.macro bvs_far address
	bvc * + 5
	jmp address
.endmacro

;loads 16-bit number into a 16-bit register
.macro LoadWord value,   low_byte,high_byte
	lda #<value
	sta low_byte
	lda #>value
	sta high_byte
.endmacro
;loads 16-bit number into a 16-bit register (in big endian)
.macro LoadWordRev value,   low_byte, high_byte
	lda #>value
	sta low_byte
	lda #<value
	sta high_byte
.endmacro

.endif