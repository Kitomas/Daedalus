.ifndef L_LABELDEF_S
.define L_LABELDEF_S 1

PPUBuffer		= $0100 ;->019F;  160 bytes


CONTROLLER1 = $4016
JOYPAD1     = $4016 ;alias
CONTROLLER2 = $4017
JOYPAD2     = $4017

;ppu registers
PPUCTRL   = $2000 ;>  write
;7  bit  0
;---- ----
;VPHB SINN
;|||| ||||
;|||| ||++- Base nametable address
;|||| ||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
;|||| |+--- VRAM address increment per CPU read/write of PPUDATA
;|||| |     (0: add 1, going across; 1: add 32, going down)
;|||| +---- Sprite pattern table address for 8x8 sprites
;||||       (0: $0000; 1: $1000; ignored in 8x16 mode)
;|||+------ Background pattern table address (0: $0000; 1: $1000)
;||+------- Sprite size (0: 8x8 pixels; 1: 8x16 pixels – see PPU OAM#Byte 1)
;|+-------- PPU master/slave select
;|          (0: read backdrop from EXT pins; 1: output color on EXT pins)
;+--------- Generate an NMI at the start of the
;           vertical blanking interval (0: off; 1: on)
PPUMASK   = $2001 ;>  write
;7  bit  0
;---- ----
;BGRs bMmG
;|||| ||||
;|||| |||+- Greyscale (0: normal color, 1: produce a greyscale display)
;|||| ||+-- 1: Show background in leftmost 8 pixels of screen, 0: Hide
;|||| |+--- 1: Show sprites in leftmost 8 pixels of screen, 0: Hide
;|||| +---- 1: Show background
;|||+------ 1: Show sprites
;||+------- Emphasize red (green on PAL/Dendy)
;|+-------- Emphasize green (red on PAL/Dendy)
;+--------- Emphasize blue		
PPUSTATUS = $2002 ;<  read		
OAMADDR   = $2003 ;>  write		
OAMDATA   = $2004 ;<> read/write	
PPUSCROLL = $2005 ;>> write 2x	
PPUADDR   = $2006 ;>> write 2x	
PPUDATA   = $2007 ;<> read/write	
OAMDMA    = $4014 ;>  write		(do this during vblank)


;palette stuff (there are 25 total palette colors registers)
PPUPAL_BGUNI = $3F00 ;        universal background color
PPUPAL_BG0   = $3F01 ;->$3F03 background palette 0
	PPUPAL_BG0_A = PPUPAL_BG0
	PPUPAL_BG0_B = PPUPAL_BG0 + 1
	PPUPAL_BG0_C = PPUPAL_BG0 + 2
PPUPAL_BG1   = $3F05 ;->$3F07 background palette 1
	PPUPAL_BG1_A = PPUPAL_BG1
	PPUPAL_BG1_B = PPUPAL_BG1 + 1
	PPUPAL_BG1_C = PPUPAL_BG1 + 2
PPUPAL_BG2   = $3F09 ;->$3F0B background palette 2
	PPUPAL_BG2_A = PPUPAL_BG2
	PPUPAL_BG2_B = PPUPAL_BG2 + 1
	PPUPAL_BG2_C = PPUPAL_BG2 + 2
PPUPAL_BG3   = $3F0D ;->$3F0F background palette 3
	PPUPAL_BG3_A = PPUPAL_BG3
	PPUPAL_BG3_B = PPUPAL_BG3 + 1
	PPUPAL_BG3_C = PPUPAL_BG3 + 2
PPUPAL_SP0   = $3F10 ;->$3F13 sprite palette 0
	PPUPAL_SP0_A = PPUPAL_SP0
	PPUPAL_SP0_B = PPUPAL_SP0 + 1
	PPUPAL_SP0_C = PPUPAL_SP0 + 2
PPUPAL_SP1   = $3F14 ;->$3F17 sprite palette 1
	PPUPAL_SP1_A = PPUPAL_SP1
	PPUPAL_SP1_B = PPUPAL_SP1 + 1
	PPUPAL_SP1_C = PPUPAL_SP1 + 2
PPUPAL_SP2   = $3F18 ;->$3F1B sprite palette 2
	PPUPAL_SP2_A = PPUPAL_SP2
	PPUPAL_SP2_B = PPUPAL_SP2 + 1
	PPUPAL_SP2_C = PPUPAL_SP2 + 2
PPUPAL_SP3   = $3F1C ;->$3F1F sprite palette 3
	PPUPAL_SP3_A = PPUPAL_SP3
	PPUPAL_SP3_B = PPUPAL_SP3 + 1
	PPUPAL_SP3_C = PPUPAL_SP3 + 2
;basic html color names with aliases
PPUPAL_WHITE     = $30 ;#$FFFFFF
PPUPAL_SILVER    = $10 ;#$C0C0C0
PPUPAL_GRAYHI    = $10 ;^^
PPUPAL_GRAY      = $00 ;#$808080
PPUPAL_GRAYLO    = $00 ;^^
PPUPAL_BLACK     = $0D ;#$000000
PPUPAL_RED       = $16 ;#$FF0000
PPUPAL_REDHI     = $16 ;^^
PPUPAL_MAROON    = $06 ;#$800000
PPUPAL_REDLO     = $06 ;^^
PPUPAL_YELLOW    = $37 ;#$FFFF00 (not that useful for ntsc)
PPUPAL_YELLOWHI  = $37 ;^^
PPUPAL_OLIVE     = $28 ;#$808000
PPUPAL_YELLOWLO  = $28 ;^^
PPUPAL_LIME      = $2a ;#$00FF00
PPUPAL_GREENHI   = $2a ;^^
PPUPAL_GREEN     = $1a ;#$008000
PPUPAL_GREENLO   = $1a ;^^
PPUPAL_AQUA      = $2c ;#$00FFFF
PPUPAL_CYANHI    = $2c ;^^
PPUPAL_TEAL      = $1c ;#$008080
PPUPAL_CYANLO    = $1c ;^^
PPUPAL_BLUE      = $12 ;#$0000FF
PPUPAL_BLUEHI    = $12 ;^^
PPUPAL_NAVY      = $01 ;#$000080
PPUPAL_BLUELO    = $01 ;^^
PPUPAL_FUCHSIA   = $24 ;#$FF00FF
PPUPAL_MAGENTAHI = $24 ;^^
PPUPAL_PURPLE    = $04 ;#$800080
PPUPAL_MAGENTALO = $04 ;^^
;ntsc grayscale values:
;fceux default palette
;$0d = 00 = 0
;$2d = 4e = 78
;$00 = 65 = 101
;$10 = ae = 174
;$3d = b7 = 183
;$30 = ff = 255


;nametable stuff
PPU_NAMETABLE_A = $2000
PPU_NAMETABLE_B = $2400
PPU_NAMETABLE_C = $2800
PPU_NAMETABLE_D = $2C00
;attribute table byte layout:
;7654 3210
;|||| ||++- Color bits 3-2 for top left quadrant of this byte
;|||| ++--- Color bits 3-2 for top right quadrant of this byte
;||++------ Color bits 3-2 for bottom left quadrant of this byte
;++-------- Color bits 3-2 for bottom right quadrant of this byte
PPU_ATTRTABLE0 = $23C0
PPU_ATTRTABLE1 = $27C0
PPU_ATTRTABLE2 = $2BC0
PPU_ATTRTABLE3 = $2FC0


;apu registers (</> xxxx xxxx = read/write bits7654 3210)
;Pulse 1 channel (> write)
APU_PULSE1_0        = $4000 ;> DDLC.NNNN  Duty, loop envelope/disable length counter, constant volume, envelope period/volume
APU_PULSE1_1        = $4001 ;> EPPP.NSSS  Sweep unit: enabled, period, negative, shift count
APU_PULSE1_2        = $4002 ;> LLLL.LLLL  Timer low
APU_PULSE1_3        = $4003 ;> LLLL.LHHH  Length counter load, timer high (also resets duty and starts envelope)
;Pulse 2 channel (> write)
APU_PULSE2_0        = $4004 ;> DDLC.NNNN  Duty, loop envelope/disable length counter, constant volume, envelope period/volume
APU_PULSE2_1        = $4005 ;> EPPP.NSSS  Sweep unit: enabled, period, negative, shift count
APU_PULSE2_2        = $4006 ;> LLLL.LLLL  Timer low
APU_PULSE2_3        = $4007 ;> LLLL.LHHH  Length counter load, timer high (also resets duty and starts envelope)
 
;Triangle channel (> write)
APU_TRIANGLE_0      = $4008 ;> CRRR.RRRR  Length counter disable/linear counter control, linear counter reload value
APU_TRIANGLE_1      = $400A ;> LLLL.LLLL  Timer low
APU_TRIANGLE_2      = $400B ;> LLLL.LHHH  Length counter load, timer high (also reloads linear counter)
 
;Noise channel (> write)
APU_NOISE_0         = $400C ;> --LC.NNNN  Loop envelope/disable length counter, constant volume, envelope period/volume
APU_NOISE_1         = $400E ;> L---.PPPP  Loop noise, noise period
APU_NOISE_2         = $400F ;> LLLL.L---  Length counter load (also starts envelope)

;DMC channel (> write)
APU_DMC_CONTROL     = $4010 ;> IL--.FFFF  IRQ enable, loop sample, frequency index
APU_DMC_DIRECT_LOAD = $4011 ;> -DDD.DDDD  Direct load
APU_DMC_ADDRESS     = $4012 ;> AAAA.AAAA  Sample address %11AAAAAA.AA000000
APU_DMC_LENGTH      = $4013 ;> LLLL.LLLL  Sample length  %0000LLLL.LLLL0001

;general registers
APU_CONTROL         = $4015 ;> ---D NT21  Control: DMC enable, length counter enables: noise, triangle, pulse 2, pulse 1 (> write)
APU_STATUS          = $4015 ;< IF-D NT21  Status: DMC interrupt, frame interrupt, length counter status: noise, triangle, pulse 2, pulse 1 (< read)
APU_FRAME_COUNTER   = $4017 ;> SD-- ----  Frame counter: 5-frame sequence, disable frame interrupt (> write)

.endif