#include "mylib.h"
#define SIN8(rad) (sin(rad)<<2)
#define COS8(rad) (sin(rad)<<2)

//zp
static uint8_t i,j;
#pragma zpsym("i")
#pragma zpsym("j")
static Reg16U temp16a;
static Reg16U temp16b;

static Reg16U amoogPosX;
static Reg16U amoogPosY;
static int16_t amoogVelX;
static int16_t amoogVelY;
#define acceleration 24 //accel 24/256ths of a pixel per frame
#define deceleration 2  //

static uint16_t starcountA;
static uint16_t starcountB;

static uint8_t str_buffer[64];

const uint8_t amoogPalette[16]={
	PPUPAL_BLACK,	//grayscale
	PPUPAL_WHITE,   //^^
	PPUPAL_GRAYHI,  //^^
	0x2D,           //^^dark gray
	PPUPAL_BLACK,
	PPUPAL_REDHI,
	PPUPAL_CYANHI,
	PPUPAL_WHITE,
	0x0D,0x0D,0x0D,0x0D, //last 2 sprite palettes are just black
	0x0D,0x0D,0x0D,0x0D  //^^
};


//invert signed int if negative, before returning it unsigned
uint16_t __fastcall__ positive16(int16_t snumber){
    if(snumber < 0){
		snumber ^= 0xffff; //two's complement
		++snumber;		   //^^
    }
    return (uint16_t)snumber;
}
//makes 16 bit number bias towards 0 by certain amount
int16_t __fastcall__ bias0_16(int16_t removeBy, int16_t snumber){
	if(snumber < 0){
		if(snumber >= -removeBy) return 0; 
		snumber += removeBy;
    } else {
        if(snumber <=  removeBy) return 0;
        snumber -= removeBy;
    }
    return snumber;
}

//write string to video memory
#define ASCII_OFFSET -0x20+1
uint8_t strprep(uint16_t addr, const char* str){
	uint8_t index=255; //so it pre-increments to 0
	while(1){
		++index;
		if(!str[index]) break;
		str_buffer[index]=str[index]+(ASCII_OFFSET);
	}
	return vmemprep(str_buffer,(uint16_t*)addr,index);
}
//write number to video memory as string
/*
uint8_t int8Uprep(uint16_t addr, uint8_t num){
	uint8_t index=0;
}
*/
uint8_t bin8prep(uint16_t addr, uint8_t num){
	for(i=0;i<8;++i){
		str_buffer[i]=ASCII_OFFSET+0x10+((num&0x80)==0x80);
		num<<=1;
	}
	return 0;
	//return vmemprep(str_buffer,(uint16_t*)addr,8);
}

void init(void){
	j=i; //so cc65 doesn't annoy me 
	i=j; //with 'defined but not used' warnings
	//turn off rendering for main init
	BITS_OFF8(ppumask,0b00011000);
	PPUMASK = ppumask; //store ram copy to actual register
	//move sprite data to ppu
	vmemprep(amoogPalette, (void*)PPUPAL_BG,sizeof(amoogPalette));
	vmemprep(amoogPalette, (void*)PPUPAL_SP,sizeof(amoogPalette));
	for(i=0;i<10;++i){
		strprep(NTADR_A(i,i),"TEST!");
		//if(i==7) strprep(NTADR_A(1,7),"LONGER TEST!");
	};
	amoogPosX.high=128-4;
	amoogPosY.high=120-4;
	OAMBuffer[0].x=amoogPosX.high;
	OAMBuffer[0].y=amoogPosY.high;
	OAMBuffer[0].index=0;
	OAMBuffer[0].attributes=0b00000001;
	//4 star sprites for a good
	OAMBuffer[1].attributes=0b00000000;
	OAMBuffer[2].attributes=0b00000000;
	OAMBuffer[3].attributes=0b00000000;
	OAMBuffer[4].attributes=0b00000000;
	//turn rendering back on
	BITS_ON(ppumask,0b00011000);
	PPUMASK = ppumask; //store ram copy to actual register
}

void main(void){ //(not optimized at all lmao)
	getButtons();
	//random16(); //not used 
	//handle input (this if-else chain could be a bit better :/)

	if(joypadState1&PAD_B) {
			 BITS_OFF8(OAMBuffer[0].attributes,0b00000001)
	} else { BITS_ON(  OAMBuffer[0].attributes,0b00000001) };
	//x
	if(       joypadState1&PAD_LEFT){
		BITS_ON(  OAMBuffer[0].attributes,0b01000000)
									amoogVelX-=acceleration;
		if(   joypadState1&PAD_B)	amoogVelX-=acceleration;
	} else if(joypadState1&PAD_RIGHT){
		BITS_OFF8(OAMBuffer[0].attributes,0b01000000)
									amoogVelX+=acceleration;
		if(   joypadState1&PAD_B)	amoogVelX+=acceleration;
	} else { amoogVelX=bias0_16(deceleration,amoogVelX); };
	//y
	if(       joypadState1&PAD_UP){
									amoogVelY-=acceleration;
		if(   joypadState1&PAD_B)	amoogVelY-=acceleration<<1;
	} else if(joypadState1&PAD_DOWN){
									amoogVelY+=acceleration;
		if(   joypadState1&PAD_B)	amoogVelY+=acceleration<<1;
	} else { amoogVelY=bias0_16(deceleration,amoogVelY); };
	
	if(joypadState1&PAD_START){
		++scrollX;
		++scrollX;
		ppuScroll(scrollX,0);
	};
	if(joypadState1&PAD_SELECT){
		--scrollX;
		--scrollX;
		ppuScroll(scrollX,0);
	};
	
	if(joypadState1&PAD_A){ reset(); };
	//update positions
	//amoog
	amoogPosX.value+=amoogVelX;
	amoogPosY.value+=amoogVelY;
	OAMBuffer[0].x=amoogPosX.high;
	OAMBuffer[0].y=amoogPosY.high;

	//stars
	starcountA+=1; //1:3.5
	starcountA%=402;
	starcountB+=4;
	starcountB%=402;
	temp16a.value=cos(starcountA);
	temp16b.value=sin(starcountB);
	OAMBuffer[1].x=124+temp16a.low;
	OAMBuffer[1].y=116+temp16b.low;
	OAMBuffer[1].index=3+(fcounterTOT%4);
	OAMBuffer[2].x=124-temp16a.low;
	OAMBuffer[2].y=116+temp16b.low;
	OAMBuffer[2].index=3+(fcounterTOT%4);
	OAMBuffer[3].x=124+temp16a.low;
	OAMBuffer[3].y=116-temp16b.low;
	OAMBuffer[3].index=3+(fcounterTOT%4);
	OAMBuffer[4].x=124-temp16a.low;
	OAMBuffer[4].y=116-temp16b.low;
	OAMBuffer[4].index=3+(fcounterTOT%4);
}

//attributes:
//76543210
//||||||||
//||||||++- Palette (4 to 7) of sprite
//|||+++--- Unimplemented (read 0)
//||+------ Priority (0: in front of background; 1: behind background)
//|+------- Flip sprite horizontally
//+-------- Flip sprite vertically

//(note to self, fixed point 6 bit numbers can
//be shifted left twice to be used conveniently as a U_Reg16)


