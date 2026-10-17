;; =============================================================
;; LIFE6502.ASM — Conway's Game of Life (1970 / 6502 Edition)
;; Puur 6502 Machinetaal op $6000 + Hardware MiniGPU Cellen!
;; Start vanaf Drive 1 met:
;;   *DRIVE 1
;;   *RUN LIFE
;; =============================================================

OSASCI   = $FFE3
OSNEWL   = $FFE7
OSWRCH   = $FFEE
TIMER_10 = $A002

GRID_A   = $0400              ; 16x8 cellen (128 bytes) huidige generatie
GRID_B   = $0480              ; 16x8 cellen (128 bytes) volgende generatie

GEN_CNT  = $70
CELL_X   = $71
CELL_Y   = $72
NB_CNT   = $73
CUR_IDX  = $74
GX_LO    = $75
GX_HI    = $76
GY_LO    = $77
GY_HI    = $78

ORG $6000

.start
   LDA #12: JSR OSWRCH
   LDA #16: JSR OSWRCH

   ; Wis GRID_A en GRID_B
   LDA #0
   LDX #127
.clr_grid
   STA GRID_A,X
   STA GRID_B,X
   DEX
   BPL clr_grid

   ; Plaats een klassieke Glider + Blinker + Beacon kolonie
   LDA #1
   ; Glider linksboven
   STA GRID_A + 2
   STA GRID_A + 19
   STA GRID_A + 33
   STA GRID_A + 34
   STA GRID_A + 35
   ; Blinker oscillator midden
   STA GRID_A + 40
   STA GRID_A + 41
   STA GRID_A + 42
   ; R-Pentomino rechts
   STA GRID_A + 27
   STA GRID_A + 28
   STA GRID_A + 42
   STA GRID_A + 43
   STA GRID_A + 59
   ; Tweede Blinker onderin
   STA GRID_A + 85
   STA GRID_A + 101
   STA GRID_A + 117

   LDA #1
   STA GEN_CNT

.gen_loop
   ; Zet cursor linksboven (VDU 31, 0, 0)
   LDA #31: JSR OSWRCH
   LDA #0:  JSR OSWRCH
   LDA #0:  JSR OSWRCH

   ; Print header in Cyaan (VDU 17, 6)
   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDX #0
.pr_hdr
   LDA msg_hdr,X
   BEQ pr_gen_num
   JSR OSASCI
   INX
   BNE pr_hdr

.pr_gen_num
   LDA GEN_CNT
   CLC
   ADC #'0'
   JSR OSASCI
   JSR OSNEWL

   ; Wis GPU scherm voor nieuwe generatie en teken levende cellen!
   LDA #16: JSR OSWRCH

   ; Loop over 8 rijen x 16 kolommen
   LDA #0: STA CELL_Y: STA CUR_IDX
.row_loop
   LDA #17: JSR OSWRCH: LDA #2: JSR OSWRCH
   LDA #'|': JSR OSASCI
   LDA #0: STA CELL_X
.col_loop
   LDX CUR_IDX
   LDA GRID_A,X
   BEQ dead_cell
   ; Levende cel! Print 'O' in Geel en teken cirkel op de GPU
   LDA #17: JSR OSWRCH: LDA #3: JSR OSWRCH
   LDA #'O': JSR OSASCI
   LDA #' ': JSR OSASCI
   JSR draw_gpu_cell
   JMP next_col
.dead_cell
   LDA #17: JSR OSWRCH: LDA #4: JSR OSWRCH
   LDA #'.': JSR OSASCI
   LDA #' ': JSR OSASCI
.next_col
   INC CUR_IDX
   INC CELL_X
   LDA CELL_X
   CMP #16
   BNE col_loop
   LDA #17: JSR OSWRCH: LDA #2: JSR OSWRCH
   LDA #'|': JSR OSASCI
   JSR OSNEWL
   INC CELL_Y
   LDA CELL_Y
   CMP #8
   BNE row_loop

   ; Bereken volgende generatie in GRID_B (Conway regels: B3/S23)
   LDX #0
.calc_loop
   STX CUR_IDX
   LDA #0: STA NB_CNT

   ; Tel de 8 buren (met wrap-around &7F)
   TXA: SEC: SBC #17: AND #$7F: TAY: LDA GRID_A,Y: CLC: ADC NB_CNT: STA NB_CNT
   TXA: SEC: SBC #16: AND #$7F: TAY: LDA GRID_A,Y: CLC: ADC NB_CNT: STA NB_CNT
   TXA: SEC: SBC #15: AND #$7F: TAY: LDA GRID_A,Y: CLC: ADC NB_CNT: STA NB_CNT
   TXA: SEC: SBC #1:  AND #$7F: TAY: LDA GRID_A,Y: CLC: ADC NB_CNT: STA NB_CNT
   TXA: CLC: ADC #1:  AND #$7F: TAY: LDA GRID_A,Y: CLC: ADC NB_CNT: STA NB_CNT
   TXA: CLC: ADC #15: AND #$7F: TAY: LDA GRID_A,Y: CLC: ADC NB_CNT: STA NB_CNT
   TXA: CLC: ADC #16: AND #$7F: TAY: LDA GRID_A,Y: CLC: ADC NB_CNT: STA NB_CNT
   TXA: CLC: ADC #17: AND #$7F: TAY: LDA GRID_A,Y: CLC: ADC NB_CNT: STA NB_CNT

   LDX CUR_IDX
   LDA NB_CNT
   CMP #3
   BEQ birth_cell
   CMP #2
   BNE kill_cell
   LDA GRID_A,X
   STA GRID_B,X
   JMP next_calc
.birth_cell
   LDA #1
   STA GRID_B,X
   JMP next_calc
.kill_cell
   LDA #0
   STA GRID_B,X
.next_calc
   INX
   BMI copy_start
   JMP calc_loop
.copy_start

   ; Kopieer GRID_B -> GRID_A
   LDX #127
.copy_grid
   LDA GRID_B,X
   STA GRID_A,X
   DEX
   BPL copy_grid

   ; Pauzeer 250 ms via hardware timer ($A002)
   LDA #25: STA TIMER_10

   INC GEN_CNT
   LDA GEN_CNT
   CMP #9
   BCS done_life
   JMP gen_loop

.done_life
   LDA #17: JSR OSWRCH: LDA #7: JSR OSWRCH
   LDX #0
.pr_done
   LDA msg_done,X
   BEQ exit_life
   JSR OSASCI
   INX
   BNE pr_done
.exit_life
   RTS

;; Teken een gloeiende GPU-cel op (200 + CELL_X*56, 760 - CELL_Y*72)
.draw_gpu_cell
   ; Kleur = Groen + Generatie
   LDA #18: JSR OSWRCH
   LDA #0:  JSR OSWRCH
   LDA GEN_CNT: CLC: ADC #1: JSR OSWRCH

   ; X = 256 + CELL_X * 48
   LDA CELL_X
   ASL A: ASL A: ASL A: ASL A ; *16
   STA GX_LO
   ASL A                      ; *32
   CLC: ADC GX_LO             ; *48
   STA GX_LO
   LDA #$01
   ADC #$00
   STA GX_HI

   ; Y = 192 + (7 - CELL_Y) * 64
   LDA #7
   SEC: SBC CELL_Y
   ASL A: ASL A: ASL A: ASL A: ASL A: ASL A ; *64
   STA GY_LO
   LDA #$01
   STA GY_HI

   ; MOVE GX, GY (PLOT 4)
   LDA #25:    JSR OSWRCH
   LDA #4:     JSR OSWRCH
   LDA GX_LO:  JSR OSWRCH
   LDA GX_HI:  JSR OSWRCH
   LDA GY_LO:  JSR OSWRCH
   LDA GY_HI:  JSR OSWRCH

   ; CIRCLE straal 18 (PLOT 199, 18, 0)
   LDA #25:    JSR OSWRCH
   LDA #199:   JSR OSWRCH
   LDA #18:    JSR OSWRCH
   LDA #0:     JSR OSWRCH
   LDA #0:     JSR OSWRCH
   LDA #0:     JSR OSWRCH
   RTS

.msg_hdr
   EQUS "=== CONWAY'S GAME OF LIFE (6502 ASM + GPU) === GEN #", 0

.msg_done
   EQUS "------------------------------------------------", 13
   EQUS "[6502 LIFE] 8 Generaties berekend op 6502 + GPU!", 13, 0

.end
SAVE start, end
