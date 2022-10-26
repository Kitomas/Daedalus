//naming convention notes that i may or may not follow:
//local variables      = lowerCamelCase
//global variables     = g_lowerCamelCase
//macros and constants = ALL_CAPS
//pointer variables    = p_XXXXXX
//non struct typedefs  = lowercase_t
//structs			   = UpperCamelCase
//enumurations         = UpperCamelCase
//c source functions   = UpperCamelCase
//asm source functions = lowerCamelCase
//enum members         = Capitalized or ALL_CAPS
//__asm__ format specifiers
//%b - Numerical 8-bit value
//%w - Numerical 16-bit value
//%l - Numerical 32-bit value
//%v - Assembler name of a global variable or function
//%o - Stack offset of a local variable
//%g - Assembler name of a C label
//%s - The argument is converted to a string
//%% - The % sign itself


//types
typedef unsigned char     uint8_t;
typedef unsigned int      uint16_t;
typedef long unsigned int uint32_t;
typedef signed char        int8_t;
typedef signed int         int16_t;
typedef long signed int    int32_t;

typedef struct {
	//sprite data is delayed by one scanline,
	//so take that +1 y offset into account before writing to oam
	uint8_t y;
	uint8_t index;
	uint8_t attributes;
	uint8_t x;
} OAM_Entry;
//attributes:
//76543210
//||||||||
//||||||++- Palette (4 to 7) of sprite
//|||+++--- Unimplemented (read 0)
//||+------ Priority (0: in front of background; 1: behind background)
//|+------- Flip sprite horizontally
//+-------- Flip sprite vertically

typedef union {
	uint16_t value;
	struct {
		uint8_t low;
		uint8_t high;
	};
} Reg16U;
typedef union {
	int16_t value;
	struct {
		int8_t low;
		int8_t high;
	};
} Reg16S;
typedef union {
	uint16_t valueU;
	struct {
		uint8_t lowU;
		uint8_t highU;
	};
	int16_t valueS;
	struct {
		int8_t lowS;
		int8_t highS;
	};
} Reg16;



//function protos

void reset(void);
void vblank(void);
void spin(void);

int16_t toIntS(int16_t);
uint16_t toIntU(uint16_t);

uint8_t random8(void);
uint16_t random16(void);

void getButtons(void);

void ppuScroll(uint8_t, uint8_t);
void ppuAddress(uint16_t*);
uint8_t vmemprep(const void*, void*, uint8_t);

int16_t sin(uint16_t);
int16_t cos(uint16_t);

//externs (finish writing each line or else confusing errors happen)

//zeropage
extern uint8_t fcounterTOT;
extern uint8_t fcounterNLG;
extern uint8_t fcounterLAG;
#pragma zpsym("fcounterTOT")
#pragma zpsym("fcounterNLG")
#pragma zpsym("fcounterLAG")

extern uint8_t ppuBufferLen;
#pragma zpsym("ppuBufferLen")

extern uint8_t* joypadState; //[2]
extern uint8_t  joypadState1;
extern uint8_t  joypadState2;
#pragma zpsym("joypadState")
#pragma zpsym("joypadState1")
#pragma zpsym("joypadState2")

extern uint16_t randomNum;
extern uint8_t  randomNuml;
extern uint8_t  randomNumh;
#pragma zpsym("randomNum")
#pragma zpsym("randomNuml")
#pragma zpsym("randomNumh")

extern uint8_t fstatus;
extern uint8_t ppuctrl;
extern uint8_t ppumask;
#pragma zpsym("fstatus")
#pragma zpsym("ppuctrl")
#pragma zpsym("ppumask")

extern uint8_t* scroll; //[2]
extern uint8_t  scrollX;
extern uint8_t  scrollY;
#pragma zpsym("scroll")
#pragma zpsym("scrollX")
#pragma zpsym("scrollY")


#define nametableBuffer ((char*)0x0100)
#define nametableBuffer_R 0x0100
#define OAMBuffer ((OAM_Entry*)0x0200) //[64] (256B total)
#define OAMBuffer_R 0x0200
//extern ??? APUBuffer

//-GLOBAL LABELS-

 //-HARDWARE ORIENTED-
#define CONTROLLER   ((char*)0x4016)
#define JOYPAD       ((char*)0x4016) //alias
#define CONTROLLER1 (*(char*)0x4016)
#define JOYPAD1     (*(char*)0x4016)
#define CONTROLLER2 (*(char*)0x4017)
#define JOYPAD2     (*(char*)0x4017)
#define JOYPAD1_R 0x4016
#define JOYPAD2_R 0x4017

//ppu registers
#define PPUCTRL (*(char*)0x2000) //>  write
#define PPUCTRL_R 0x2000
//7  bit  0
//---- ----
//VPHB SINN
//|||| ||||
//|||| ||++- Base nametable address
//|||| ||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
//|||| |+--- VRAM address increment per CPU read/write of PPUDATA
//|||| |     (0: add 1, going across; 1: add 32, going down)
//|||| +---- Sprite pattern table address for 8x8 sprites
//||||       (0: $0000; 1: $1000; ignored in 8x16 mode)
//|||+------ Background pattern table address (0: $0000; 1: $1000)
//||+------- Sprite size (0: 8x8 pixels; 1: 8x16 pixels – see PPU OAM#Byte 1)
//|+-------- PPU master/slave select
//|          (0: read backdrop from EXT pins; 1: output color on EXT pins)
//+--------- Generate an NMI at the start of the
//           vertical blanking interval (0: off; 1: on)
#define PPUMASK (*(char*)0x2001) //>  write
#define PPUMASK_R 0x2001
//7  bit  0
//---- ----
//BGRs bMmG
//|||| ||||
//|||| |||+- Greyscale (0: normal color, 1: produce a greyscale display)
//|||| ||+-- 1: Show background in leftmost 8 pixels of screen, 0: Hide
//|||| |+--- 1: Show sprites in leftmost 8 pixels of screen, 0: Hide
//|||| +---- 1: Show background
//|||+------ 1: Show sprites
//||+------- Emphasize red (green on PAL/Dendy)
//|+-------- Emphasize green (red on PAL/Dendy)
//+--------- Emphasize blue		
#define PPUSTATUS (*(char*)0x2002) //<  read		
#define OAMADDR   (*(char*)0x2003) //>  write		
#define OAMDATA   (*(char*)0x2004) //<> read/write	
#define PPUSCROLL (*(char*)0x2005) //>> write 2x	
#define PPUADDR   (*(char*)0x2006) //>> write 2x	
#define PPUDATA   (*(char*)0x2007) //<> read/write	
#define OAMDMA    (*(char*)0x4014) //>  write (do this during vblank)
#define PPUSTATUS_R 0x2002
#define OAMADDR_R   0x2003
#define OAMDATA_R   0x2004
#define PPUSCROLL_R 0x2005
#define PPUADDR_R   0x2006
#define PPUDATA_R   0x2007
#define OAMDMA_R    0x4014

//palette stuff
#define PPUPAL_BG    0x3F00
#define PPUPAL_BGUNI 0x3F00 //        universal background color
#define PPUPAL_BG0   0x3F01 //->$3F03 background palette 0
#define PPUPAL_BG1   0x3F05 //->$3F07 background palette 1
#define PPUPAL_BG2   0x3F09 //->$3F0B background palette 2
#define PPUPAL_BG3   0x3F0D //->$3F0F background palette 3
#define PPUPAL_SP    0x3F10
#define PPUPAL_SP0   0x3F10 //->$3F13 sprite palette 0
#define PPUPAL_SP1   0x3F14 //->$3F17 sprite palette 1
#define PPUPAL_SP2   0x3F18 //->$3F1B sprite palette 2
#define PPUPAL_SP3   0x3F1C //->$3F1F sprite palette 3
//basic html color names with aliases
#define PPUPAL_WHITE     0x30 //#$FFFFFF
#define PPUPAL_SILVER    0x10 //#$C0C0C0
#define PPUPAL_GRAYHI    0x10 //^^		
#define PPUPAL_GRAY      0x00 //#$808080
#define PPUPAL_GRAYLO    0x00 //^^		
#define PPUPAL_BLACK     0x0D //#$000000
#define PPUPAL_RED       0x16 //#$FF0000
#define PPUPAL_REDHI     0x16 //^^		
#define PPUPAL_MAROON    0x06 //#$800000
#define PPUPAL_REDLO     0x06 //^^		
#define PPUPAL_YELLOW    0x37 //#$FFFF00 (not that useful for ntsc)
#define PPUPAL_YELLOWHI  0x37 //^^		
#define PPUPAL_OLIVE     0x28 //#$808000
#define PPUPAL_YELLOWLO  0x28 //^^		
#define PPUPAL_LIME      0x2a //#$00FF00
#define PPUPAL_GREENHI   0x2a //^^		
#define PPUPAL_GREEN     0x1a //#$008000
#define PPUPAL_GREENLO   0x1a //^^		
#define PPUPAL_AQUA      0x2c //#$00FFFF
#define PPUPAL_CYANHI    0x2c //^^		
#define PPUPAL_TEAL      0x1c //#$008080
#define PPUPAL_CYANLO    0x1c //^^		
#define PPUPAL_BLUE      0x12 //#$0000FF
#define PPUPAL_BLUEHI    0x12 //^^		
#define PPUPAL_NAVY      0x01 //#$000080
#define PPUPAL_BLUELO    0x01 //^^		
#define PPUPAL_FUCHSIA   0x24 //#$FF00FF
#define PPUPAL_MAGENTAHI 0x24 //^^		
#define PPUPAL_PURPLE    0x04 //#$800080
#define PPUPAL_MAGENTALO 0x04 //^^		
//grayscale approximation
//(ntsc grayscale=$0d,$2d,$00,$10,$3d,$30)
//$0d = 00 = 0
//$2d = 4e = 78
//$00 = 65 = 101
//$10 = ae = 174
//$3d = b7 = 183
//$30 = ff = 255

//nametable stuff
#define PPU_NAMETABLE_A 0x2000
#define PPU_NAMETABLE_B 0x2400
#define PPU_NAMETABLE_C 0x2800
#define PPU_NAMETABLE_D 0x2C00
//attribute table byte layout:
//7654 3210
//|||| ||++- Color bits 3-2 for top left quadrant of this byte
//|||| ++--- Color bits 3-2 for top right quadrant of this byte
//||++------ Color bits 3-2 for bottom left quadrant of this byte
//++-------- Color bits 3-2 for bottom right quadrant of this byte
#define PPU_ATTRTABLE_A 0x23C0
#define PPU_ATTRTABLE_B 0x27C0
#define PPU_ATTRTABLE_C 0x2BC0
#define PPU_ATTRTABLE_D 0x2FC0


#define SPIN() fstatus|=0b10000000; spin();
#define BITS_OFF8(var,bits) var &= bits^0xff;
#define BITS_OFF16(var,bits) var &= bits^0xffff;
#define BITS_ON(var,bits) var |= bits;

//realized my joypad read does this backwards,
//so now the buttons are in reverse order (compared to neslib)
#define PAD_A			0x80
#define PAD_B			0x40
#define PAD_SELECT		0x20
#define PAD_START		0x10
#define PAD_UP			0x08
#define PAD_DOWN		0x04
#define PAD_LEFT		0x02
#define PAD_RIGHT		0x01

//below yoinked from neslib
#define NULL			0
#define TRUE			1
#define FALSE			0

#define NTADR_A(x,y) 	(PPU_NAMETABLE_A|(((y)<<5)|(x)))
#define NTADR_B(x,y) 	(PPU_NAMETABLE_B|(((y)<<5)|(x)))
#define NTADR_C(x,y) 	(PPU_NAMETABLE_C|(((y)<<5)|(x)))
#define NTADR_D(x,y) 	(PPU_NAMETABLE_D|(((y)<<5)|(x)))