.ifndef L_LABELDEF_ZP_S
.define L_LABELDEF_ZP_S 1

.export _fcounterTOT,_fcounterNLG,_fcounterLAG
.export _ppuBufferLen
.export _joypadState,_joypadState1,_joypadState2
.export _randomNum,_randomNuml,_randomNumh
.export _fstatus,_ppuctrl,_ppumask
.export _scroll,_scrollX,_scrollY

fcounter:             .res 3   ;global frame counters
_fcounterTOT  = fcounter       ;^^total frames   (0-> 59)
_fcounterNLG  = fcounter+1     ;^^non-lag frames (0-> 59)
_fcounterLAG  = fcounter+2     ;^^lag frames     (0->255)
_ppuBufferLen:        .res 1   ;current length of vram buffer
r16a:                 .res 3   ;register 16 a
r16al        = r16a            ;^^
r16ah        = r16a+1          ;^^
swap         = r16a+2          ;^^(very) temporary scratch space
r16b:                 .res 2   ;register 16 b
r16bl        = r16b            ;^^
r16bh        = r16b+1          ;^^
r16c:                 .res 2   ;register 16 c
r16cl        = r16c            ;^^
r16ch        = r16c+1          ;^^
_joypadState:         .res 2   ;last controller reads
_joypadState1 = _joypadState   ;^^
_joypadState2 = _joypadState+1 ;^^
_randomNum:           .res 2   ;current pseudorandomly generated number
_randomNuml   = _randomNum     ;^^
_randomNumh   = _randomNum+1   ;^^
;frame status flags:
;bit 7=main loop finished?
;bit 6=do ppu upload?
;bit 5=apply scroll?
_fstatus:             .res 1   ;see above
_ppuctrl:             .res 1   ;copies of ppu registers (which are normally write only)
_ppumask:             .res 1   ;^^
_scroll:              .res 2   ;scroll state
_scrollX      = _scroll        ;^^
_scrollY      = _scroll+1      ;^^
scratch:              .res 12

.endif