;iNES header for nrom mapper
	.byte "NES",$1a ; Constant; "File signature,MS-DOS EOF"
	.byte $02       ; Size of PRG ROM in 16kB units (1 or 2 for NROM-128 or NROM-256 respectively)
	.byte $01       ; Same as above, but for CHR ROM in 8kB units
	.byte %00000001 ; Flags 6  (see below); mapper 0, vertical mirroring
	.byte %00000000 ; Flags 7  (see below); mapper 0
	.byte $00       ; Flags 8  (see below)
	.byte $00       ; Flags 9  (see below)
	.byte $00       ; Flags 10 (see below)
	.byte 0,0,0,0,0 ; Padding/unused bytes

;No trainer is used, so no bytes need to be added (or is that an nes2.0 feature? I forget)

;FLAGS 6:
;========
;76543210
;||||||||
;|||||||+- Mirroring: 0: horizontal (vertical arrangement) (CIRAM A10 = PPU A11)
;|||||||              1: vertical (horizontal arrangement) (CIRAM A10 = PPU A10)
;||||||+-- 1: Cartridge contains battery-backed PRG RAM ($6000-7FFF) or other persistent memory
;|||||+--- 1: 512-byte trainer at $7000-$71FF (stored before PRG data)
;||||+---- 1: Ignore mirroring control or above mirroring bit; instead provide four-screen VRAM
;++++----- Lower nybble of mapper number

;FLAGS 7:
;========
;76543210
;||||||||
;|||||||+- VS Unisystem
;||||||+-- PlayChoice-10 (8KB of Hint Screen data stored after CHR data)
;||||++--- If equal to 2, flags 8-15 are in NES 2.0 format
;++++----- Upper nybble of mapper number

;FLAGS 8:
;76543210
;||||||||
;++++++++- PRG RAM size

;FLAGS 9:
;76543210
;||||||||
;|||||||+- TV system (0: NTSC; 1: PAL)
;+++++++-- Reserved, set to zero

;FLAGS 10:
;76543210
;  ||  ||
;  ||  ++- TV system (0: NTSC; 2: PAL; 1/3: dual compatible)
;  |+----- PRG RAM ($6000-$7FFF) (0: present; 1: not present)
;  +------ 0: Board has no bus conflicts; 1: Board has bus conflicts
