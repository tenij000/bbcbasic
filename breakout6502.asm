;; =============================================================
;; BREAKOUT6502.ASM — Wozniak's Little Brick Out / Breakout (1976)
;; Puur 6502 Machinetaal op $6000 + Hardware MiniGPU Arcade!
;; Start vanaf Drive 1 met:
;;   *DRIVE 1
;;   *RUN BREAKOUT
;; =============================================================

OSASCI   = $FFE3
OSNEWL   = $FFE7
OSWRCH   = $FFEE
TIMER_10 = $A002

BALL_X   = $70
BALL_Y   = $71
VEL_X    = $72
VEL_Y    = $73
PAD_X    = $74
SCORE    = $75
FRAME    = $76
BRICKS   = $0400              ; 16 bakstenen (1 = heel, 0 = kapot)

ORG $6000

.start
   LDA #12: JSR OSWRCH
   LDA #16: JSR OSWRCH

   ; Zet alle 16 bakstenen klaar
   LDA #1
   LDX #15
.init_b
   STA BRICKS,X
   DEX
   BPL init_b

   ; Startpositie bal en batje
   LDA #6:  STA BALL_X
   LDA #5:  STA BALL_Y
   LDA #1:  STA VEL_X
   LDA #$FF: STA VEL_Y        ; Beweeg omhoog (-1)
   LDA #5:  STA PAD_X
   LDA #0:  STA SCORE
   LDA #0:  STA FRAME

.game_loop
   ; Zet tekstcursor op (0,0)
   LDA #31: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #0: JSR OSWRCH

   ; Print arcade scoreboard in Geel (VDU 17, 3)
   LDA #17: JSR OSWRCH: LDA #3: JSR OSWRCH
   LDX #0
.pr_hdr
   LDA msg_hdr,X
   BEQ pr_sc
   JSR OSASCI
   INX
   BNE pr_hdr
.pr_sc
   LDA SCORE
   CLC: ADC #'0'
   JSR OSASCI
   LDA #'0': JSR OSASCI
   JSR OSNEWL

   ; Teken bovenrand
   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDX #0
.pr_top
   LDA msg_wall,X
   BEQ pr_bricks_row
   JSR OSASCI
   INX
   BNE pr_top

.pr_bricks_row
   ; Teken 2 rijen van 8 gekleurde bakstenen (en op de GPU!)
   LDA #16: JSR OSWRCH        ; Wis GPU framebuffer voor vloeiende animatie
   LDX #0
   LDA #'|': JSR OSASCI
.b_row0
   LDA BRICKS,X
   BEQ b0_empty
   LDA #17: JSR OSWRCH: LDA #1: JSR OSWRCH
   LDA #'[': JSR OSASCI: LDA #'=': JSR OSASCI: LDA #']': JSR OSASCI
   JSR gpu_draw_brick
   JMP b0_next
.b0_empty
   LDA #' ': JSR OSASCI: JSR OSASCI: JSR OSASCI
.b0_next
   INX
   CPX #8
   BNE b_row0
   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDA #'|': JSR OSASCI: JSR OSNEWL

   LDA #'|': JSR OSASCI
.b_row1
   LDA BRICKS,X
   BEQ b1_empty
   LDA #17: JSR OSWRCH: LDA #2: JSR OSWRCH
   LDA #'[': JSR OSASCI: LDA #'#': JSR OSASCI: LDA #']': JSR OSASCI
   JSR gpu_draw_brick
   JMP b1_next
.b1_empty
   LDA #' ': JSR OSASCI: JSR OSASCI: JSR OSASCI
.b1_next
   INX
   CPX #16
   BNE b_row1
   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDA #'|': JSR OSASCI: JSR OSNEWL

   ; Teken speelveld (rijen Y = 2..7)
   LDY #2
.field_row
   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDA #'|': JSR OSASCI
   LDX #0
.field_col
   CPY BALL_Y
   BNE not_ball
   CPX BALL_X
   BNE not_ball
   LDA #17: JSR OSWRCH: LDA #7: JSR OSWRCH
   LDA #'O': JSR OSASCI
   JMP next_fcol
.not_ball
   LDA #' ': JSR OSASCI
.next_fcol
   INX
   CPX #24
   BNE field_col
   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDA #'|': JSR OSASCI: JSR OSNEWL
   INY
   CPY #8
   BNE field_row

   ; Teken batje (paddle) onderaan
   LDA #'|': JSR OSASCI
   LDX #0
.pad_loop
   TXA
   SEC: SBC PAD_X
   BCC pad_sp
   CMP #5
   BCS pad_sp
   LDA #17: JSR OSWRCH: LDA #3: JSR OSWRCH
   LDA #'=': JSR OSASCI
   JMP pad_next
.pad_sp
   LDA #' ': JSR OSASCI
.pad_next
   INX
   CPX #24
   BNE pad_loop
   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDA #'|': JSR OSASCI: JSR OSNEWL

   ; Teken de bal en het batje ook op de 720p HDMI MiniGPU!
   JSR gpu_draw_ball_and_pad

   ; Update bal-fysica
   LDA BALL_X: CLC: ADC VEL_X: STA BALL_X
   CMP #1
   BCS chk_rx
   LDA #1: STA VEL_X
.chk_rx
   LDA BALL_X
   CMP #22
   BCC update_y
   LDA #$FF: STA VEL_X

.update_y
   LDA BALL_Y: CLC: ADC VEL_Y: STA BALL_Y
   CMP #2
   BCS chk_bottom
   ; Check botsing met baksteen!
   LDA BALL_X: LSR A: LSR A: AND #$07
   CLC: ADC #8
   TAX
   LDA BRICKS,X
   BEQ try_row0
   LDA #0: STA BRICKS,X
   INC SCORE
   JMP bounce_down
.try_row0
   TXA: AND #$07: TAX
   LDA BRICKS,X
   BEQ bounce_down
   LDA #0: STA BRICKS,X
   INC SCORE
.bounce_down
   LDA #1: STA VEL_Y
   LDA #2: STA BALL_Y
   JMP move_ai_pad

.chk_bottom
   LDA BALL_Y
   CMP #7
   BCC move_ai_pad
   LDA #$FF: STA VEL_Y
   LDA #6: STA BALL_Y

.move_ai_pad
   ; Laat het batje automatisch achter de bal aan bewegen (Auto-Arcade Demo)
   LDA BALL_X
   SEC: SBC #2
   BPL pad_ok
   LDA #0
.pad_ok
   CMP #19
   BCC pad_set
   LDA #19
.pad_set
   STA PAD_X

   ; Hardware pauze 120 ms (12 x 10ms)
   LDA #12: STA TIMER_10

   INC FRAME
   LDA FRAME
   CMP #20
   BCS done_breakout
   JMP game_loop

.done_breakout
   LDA #17: JSR OSWRCH: LDA #7: JSR OSWRCH
   LDX #0
.pr_end
   LDA msg_done,X
   BEQ exit_brk
   JSR OSASCI
   INX
   BNE pr_end
.exit_brk
   RTS

;; Teken baksteen X op de MiniGPU
.gpu_draw_brick
   TXA: PHA
   LDA #18: JSR OSWRCH: LDA #0: JSR OSWRCH
   TXA: AND #$07: CLC: ADC #1: JSR OSWRCH
   PLA: PHA
   AND #$07
   ASL A: ASL A: ASL A: ASL A: ASL A: ASL A ; *64
   PHA
   ; MOVE X*64 + 380, Y=780
   LDA #25: JSR OSWRCH: LDA #4: JSR OSWRCH
   PLA: PHA: JSR OSWRCH
   LDA #2: JSR OSWRCH
   LDA #$EC: JSR OSWRCH: LDA #$02: JSR OSWRCH
   ; DRAW X*64 + 428, Y=780
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   PLA: CLC: ADC #48: JSR OSWRCH
   LDA #2: JSR OSWRCH
   LDA #$EC: JSR OSWRCH: LDA #$02: JSR OSWRCH
   PLA: TAX
   RTS

;; Teken bal (CIRCLE) en batje (LINE) op de MiniGPU
.gpu_draw_ball_and_pad
   ; Bal in Wit (GCOL 0, 7)
   LDA #18: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #7: JSR OSWRCH
   LDA #25: JSR OSWRCH: LDA #4: JSR OSWRCH
   LDA BALL_X: ASL A: ASL A: ASL A: ASL A: ASL A: JSR OSWRCH
   LDA #2: JSR OSWRCH
   LDA #8: SEC: SBC BALL_Y: ASL A: ASL A: ASL A: ASL A: ASL A: ASL A: JSR OSWRCH
   LDA #1: JSR OSWRCH
   ; Cirkel straal 16
   LDA #25: JSR OSWRCH: LDA #199: JSR OSWRCH
   LDA #16: JSR OSWRCH: LDA #0: JSR OSWRCH
   LDA #0: JSR OSWRCH: LDA #0: JSR OSWRCH
   RTS

.msg_hdr
   EQUS "=== WOZNIAK LITTLE BRICK OUT (1976) === SCORE: 00", 0
.msg_wall
   EQUS "+------------------------+", 13, 0
.msg_done
   EQUS "+------------------------+", 13
   EQUS "[6502 BREAKOUT] Arcade Demo voltooid op 6502 + MiniGPU!", 13, 0

.end
SAVE start, end
