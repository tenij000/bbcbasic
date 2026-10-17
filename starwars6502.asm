;; =============================================================
;; STARWARS6502.ASM — 1983 Atari/Acorn 6502 3D Vector Trench Run
;; Gebruikt Hardware Bresenham Lijnen, Cirkels & Sprites op $6000!
;; Start vanaf Drive 1 met:
;;   *DRIVE 1
;;   *RUN STARWARS
;; =============================================================

OSASCI   = $FFE3
OSNEWL   = $FFE7
OSWRCH   = $FFEE
TIMER_10 = $A002

DIST     = $70
TIE_X    = $71
FRAME    = $72

ORG $6000

.start
   LDA #12: JSR OSWRCH
   LDA #16: JSR OSWRCH

   ; Activeer Hardware Sprite #0 als X-Wing Vizier midden op het scherm!
   ; PLOT 200, 0, 0 (Selecteer Sprite 0)
   LDA #25: JSR OSWRCH: LDA #200: JSR OSWRCH
   LDA #0:  JSR OSWRCH: LDA #0:   JSR OSWRCH
   LDA #0:  JSR OSWRCH: LDA #0:   JSR OSWRCH
   ; PLOT 202, 1, 0 (Activeer Sprite 0)
   LDA #25: JSR OSWRCH: LDA #202: JSR OSWRCH
   LDA #1:  JSR OSWRCH: LDA #0:   JSR OSWRCH
   LDA #0:  JSR OSWRCH: LDA #0:   JSR OSWRCH

   LDA #12
   STA DIST
   LDA #0
   STA FRAME

.trench_loop
   ; Zet tekstcursor op (0,0)
   LDA #31: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #0: JSR OSWRCH

   ; Print Red-5 Targeting Computer HUD in Geel (VDU 17, 3)
   LDA #17: JSR OSWRCH: LDA #3: JSR OSWRCH
   LDX #0
.pr_hud
   LDA msg_hud,X
   BEQ pr_dist
   JSR OSASCI
   INX
   BNE pr_hud

.pr_dist
   LDA #'0'
   JSR OSASCI
   LDA DIST
   CLC: ADC #'0'
   JSR OSASCI
   LDA #'0': JSR OSASCI
   LDA #'0': JSR OSASCI
   JSR OSNEWL

   ; Print ASCII 3D Trench View
   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDX #0
.pr_trench
   LDA msg_trench,X
   BEQ gpu_vector_scene
   JSR OSASCI
   INX
   BNE pr_trench

.gpu_vector_scene
   ; Wis GPU scherm en teken 3D perspectief-lijnen naar verdwijnpunt (640, 512)
   LDA #16: JSR OSWRCH

   ; 1. Teken 4 groene 3D Trench perspectieflijnen vanuit (640, 512) naar de hoeken
   LDA #18: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #2: JSR OSWRCH

   ; Linksboven (0, 1023) -> Midden (640, 512)
   JSR move_center
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   LDA #0:  JSR OSWRCH: LDA #0: JSR OSWRCH
   LDA #$FF: JSR OSWRCH: LDA #$03: JSR OSWRCH

   ; Rechtsboven (1279, 1023) -> Midden (640, 512)
   JSR move_center
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   LDA #$FF: JSR OSWRCH: LDA #$04: JSR OSWRCH
   LDA #$FF: JSR OSWRCH: LDA #$03: JSR OSWRCH

   ; Linksonder (0, 0) -> Midden (640, 512)
   JSR move_center
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   LDA #0: JSR OSWRCH: LDA #0: JSR OSWRCH
   LDA #0: JSR OSWRCH: LDA #0: JSR OSWRCH

   ; Rechtsonder (1279, 0) -> Midden (640, 512)
   JSR move_center
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   LDA #$FF: JSR OSWRCH: LDA #$04: JSR OSWRCH
   LDA #0:   JSR OSWRCH: LDA #0:   JSR OSWRCH

   ; 2. Teken naderende TIE-Fighter cockpit (Cyaan Cirkel + Vleugels)
   LDA #18: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #6: JSR OSWRCH
   JSR move_center
   LDA #25: JSR OSWRCH: LDA #199: JSR OSWRCH
   LDA FRAME: ASL A: ASL A: CLC: ADC #24: JSR OSWRCH
   LDA #0: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #0: JSR OSWRCH

   ; 3. Teken rode X-Wing Laserstralen vanuit de hoeken naar het doelwit!
   LDA #18: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #1: JSR OSWRCH
   JSR move_center
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   LDA #120: JSR OSWRCH: LDA #0: JSR OSWRCH
   LDA #80:  JSR OSWRCH: LDA #0: JSR OSWRCH

   JSR move_center
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   LDA #$00: JSR OSWRCH: LDA #$04: JSR OSWRCH
   LDA #80:  JSR OSWRCH: LDA #0:   JSR OSWRCH

   ; Beweeg ook Hardware Sprite #0 rond het vizier (PLOT 201, X, Y)
   LDA #25: JSR OSWRCH: LDA #201: JSR OSWRCH
   LDA FRAME: ASL A: ASL A: CLC: ADC #$60: JSR OSWRCH
   LDA #$02: JSR OSWRCH
   LDA #$68: JSR OSWRCH: LDA #$01: JSR OSWRCH

   ; Hardware pauze 150 ms
   LDA #15: STA TIMER_10

   INC FRAME
   DEC DIST
   BNE jmp_trench

   ; Doelwit geraakt! Teken grote gele explosie-cirkels!
   LDA #18: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #3: JSR OSWRCH
   JSR move_center
   LDA #25: JSR OSWRCH: LDA #199: JSR OSWRCH
   LDA #160: JSR OSWRCH: LDA #0: JSR OSWRCH
   LDA #0: JSR OSWRCH: LDA #0: JSR OSWRCH

   LDA #17: JSR OSWRCH: LDA #2: JSR OSWRCH
   LDX #0
.pr_win
   LDA msg_win,X
   BEQ exit_sw
   JSR OSASCI
   INX
   BNE pr_win

.exit_sw
   LDA #17: JSR OSWRCH: LDA #7: JSR OSWRCH
   RTS

.jmp_trench
   JMP trench_loop

;; Verplaats GPU cursor naar (640, 512) = ($0280, $0200)
.move_center
   LDA #25:  JSR OSWRCH
   LDA #4:   JSR OSWRCH
   LDA #$80: JSR OSWRCH
   LDA #$02: JSR OSWRCH
   LDA #$00: JSR OSWRCH
   LDA #$02: JSR OSWRCH
   RTS

.msg_hud
   EQUS "=== STAR WARS 6502 VECTOR TRENCH RUN === AFSTAND: ", 0

.msg_trench
   EQUS "   \                        /   ", 13
   EQUS "    \   \              /   /    ", 13
   EQUS "     \   \   |-OO-|   /   /     ", 13
   EQUS "      \   \    ><    /   /      ", 13
   EQUS "     /   /  [TARGET]  \   \     ", 13
   EQUS "    /   /              \   \    ", 13
   EQUS "   /                        \   ", 13, 0

.msg_win
   EQUS "================================================", 13
   EQUS "  DIRECT HIT! DEATH STAR EXHAUST PORT DESTROYED!", 13
   EQUS "  THE FORCE IS STRONG WITH YOUR 6502 MINIGPU!   ", 13
   EQUS "================================================", 13, 0

.end
SAVE start, end
