;; =============================================================
;; MATRIX6502.ASM — Puur 6502 Machinetaal Programma (ORG $6000)
;; Geen enkele regel BASIC! Draait direct vanaf SD-kaart met:
;;   *RUN MATRIX
;; =============================================================

OSWRCH   = $FFEE
OSNEWL   = $FFE7
GPU_PORT = $A001
TIMER_10 = $A002

ORG $6000

.start
   ; 1. Wis tekstscherm (VDU 12) en grafisch scherm (VDU 16)
   LDA #12: JSR OSWRCH
   LDA #16: STA GPU_PORT

   ; 2. Zet tekstkleur op Groen (VDU 17, 2) en print 6502 titel
   LDA #17: JSR OSWRCH
   LDA #2:  JSR OSWRCH
   LDX #0
.print_hdr
   LDA msg_title,X
   BEQ anim_start
   JSR OSWRCH
   INX
   BNE print_hdr

.anim_start
   ; 3. Teken geanimeerde Radar / Laser Cirkels vanuit (640, 360)
   LDY #12
.ring_loop
   ; Kies kleur (GCOL 0, Y)
   LDA #18: STA GPU_PORT
   LDA #0:  STA GPU_PORT
   TYA:     STA GPU_PORT

   ; Verplaats GPU-cursor naar midden van het scherm: X=640 ($0280), Y=360 ($0168)
   LDA #25:  STA GPU_PORT
   LDA #4:   STA GPU_PORT
   LDA #$80: STA GPU_PORT
   LDA #$02: STA GPU_PORT
   LDA #$68: STA GPU_PORT
   LDA #$01: STA GPU_PORT

   ; Teken hardware cirkel (PLOT 199, straal=Y, 0)
   LDA #25:  STA GPU_PORT
   LDA #199: STA GPU_PORT
   TYA:      STA GPU_PORT
   LDA #0:   STA GPU_PORT
   LDA #0:   STA GPU_PORT
   LDA #0:   STA GPU_PORT

   ; Teken ook een laserstraal vanuit (640,360) naar buiten!
   LDA #25:  STA GPU_PORT
   LDA #5:   STA GPU_PORT
   TYA: ASL A: STA GPU_PORT
   LDA #$01: STA GPU_PORT
   TYA:      STA GPU_PORT
   LDA #$01: STA GPU_PORT

   ; Korte hardware pauze (20 ms = 2 x 10ms) voor echt jaren '80 animatie-effect!
   LDA #2: STA TIMER_10

   TYA
   CLC
   ADC #6
   TAY
   CPY #240
   BCC ring_loop

   ; 4. Zet tekstkleur terug op Wit (VDU 17, 7) en print klaar-melding
   LDA #17: JSR OSWRCH
   LDA #7:  JSR OSWRCH
   LDX #0
.print_ftr
   LDA msg_done,X
   BEQ exit_to_mos
   JSR OSWRCH
   INX
   BNE print_ftr

.exit_to_mos
   RTS                       ; Keer netjes terug naar het SD-MOS (>)!

.msg_title
   EQUS "================================================", 13, 10
   EQUS "  PUUR 6502 MACHINETAAL PROGRAMMA (ORG $6000)   ", 13, 10
   EQUS "  Gestart vanaf MicroSD-kaart met: *RUN MATRIX  ", 13, 10
   EQUS "================================================", 13, 10, 0

.msg_done
   EQUB 13, 10
   EQUS "[6502 ASM] Radar & Laser animatie voltooid!", 13, 10
   EQUS "Terug naar de prompt via 6502 RTS instructie.", 13, 10, 0

.end
SAVE start, end
