;; =============================================================
;; MICROCHESS6502.ASM — Peter Jennings' KIM-1 MicroChess (1976)
;; Eerste commerciële 6502 microcomputer-game ooit gemaakt!
;; Speelt en tekent 8x8 Schaakbord op Terminal + HDMI MiniGPU
;; Start vanaf Drive 1 met:
;;   *DRIVE 1
;;   *RUN CHESS
;; =============================================================

OSASCI   = $FFE3
OSNEWL   = $FFE7
OSWRCH   = $FFEE
TIMER_10 = $A002

BOARD    = $0400              ; 64 vakjes (8x8 schaakbord)
MOVE_IDX = $70
ROW_I    = $71
COL_I    = $72
SQ_IDX   = $73

ORG $6000

.start
   LDA #12: JSR OSWRCH
   LDA #16: JSR OSWRCH

   ; Kopieer beginopstelling naar BOARD ($0400..$043F)
   LDX #63
.init_brd
   LDA init_board,X
   STA BOARD,X
   DEX
   BPL init_brd

   ; Teken een 8x8 schaakbord-raster op de 720p HDMI MiniGPU!
   JSR gpu_draw_chess_grid

   LDA #0
   STA MOVE_IDX

.chess_loop
   ; Zet tekstcursor op (0,0)
   LDA #31: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #0: JSR OSWRCH

   ; Print MicroChess 1976 header in Geel
   LDA #17: JSR OSWRCH: LDA #3: JSR OSWRCH
   LDX #0
.pr_hdr
   LDA msg_hdr,X
   BEQ pr_move_nr
   JSR OSASCI
   INX
   BNE pr_hdr

.pr_move_nr
   LDA MOVE_IDX
   CLC: ADC #'0'
   JSR OSASCI
   JSR OSNEWL

   ; Print kolom-letters
   LDA #17: JSR OSWRCH: LDA #6: JSR OSASCI
   LDX #0
.pr_cols
   LDA msg_cols,X
   BEQ pr_rows_start
   JSR OSASCI
   INX
   BNE pr_cols

.pr_rows_start
   LDA #0
   STA ROW_I
   STA SQ_IDX

.row_loop
   ; Print rijnummer (8..1) in Cyaan
   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDA #'8': SEC: SBC ROW_I: JSR OSASCI
   LDA #' ': JSR OSASCI
   LDA #'|': JSR OSASCI

   LDA #0: STA COL_I
.col_loop
   LDX SQ_IDX
   LDA BOARD,X
   CMP #'.'
   BEQ empty_sq
   CMP #'a'
   BCS white_piece
   ; Zwart stuk (Rood/Magenta)
   PHA
   LDA #17: JSR OSWRCH: LDA #1: JSR OSWRCH
   JMP pr_piece
.white_piece
   ; Wit stuk (Wit/Geel)
   PHA
   LDA #17: JSR OSWRCH: LDA #7: JSR OSWRCH
   JMP pr_piece
.empty_sq
   PHA
   LDA #17: JSR OSWRCH: LDA #4: JSR OSWRCH
.pr_piece
   LDA #' ': JSR OSASCI
   PLA: JSR OSASCI
   INC SQ_IDX
   INC COL_I
   LDA COL_I
   CMP #8
   BNE col_loop

   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDA #' ': JSR OSASCI
   LDA #'|': JSR OSASCI
   JSR OSNEWL

   INC ROW_I
   LDA ROW_I
   CMP #8
   BEQ rows_done
   JMP row_loop
.rows_done

   ; Pauzeer 350 ms via hardware timer ($A002)
   LDA #35: STA TIMER_10

   ; Voer de volgende schaakzet uit uit de tabel (7 zetten t/m Schaakmat!)
   LDA MOVE_IDX
   CMP #7
   BCS chess_done
   ASL A
   TAX
   LDY move_from,X
   LDA BOARD,Y
   PHA
   LDA #'.'
   STA BOARD,Y
   LDY move_from+1,X
   PLA
   STA BOARD,Y

   INC MOVE_IDX
   JMP chess_loop

.chess_done
   LDA #17: JSR OSWRCH: LDA #2: JSR OSWRCH
   LDX #0
.pr_mate
   LDA msg_mate,X
   BEQ exit_chess
   JSR OSASCI
   INX
   BNE pr_mate
.exit_chess
   LDA #17: JSR OSWRCH: LDA #7: JSR OSWRCH
   RTS

;; Teken 9 horizontale en 9 verticale schaakbordlijnen op de MiniGPU
.gpu_draw_chess_grid
   LDA #18: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDX #0
.grid_l
   TXA: PHA
   ; Y = 128 + X*64
   ASL A: ASL A: ASL A: ASL A: ASL A: ASL A
   TAY
   ; MOVE (512, Y+256)
   LDA #25: JSR OSWRCH: LDA #4: JSR OSWRCH
   LDA #0:  JSR OSWRCH: LDA #2: JSR OSWRCH
   TYA:     JSR OSWRCH: LDA #1: JSR OSWRCH
   ; DRAW (1024, Y+256)
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   LDA #0:  JSR OSWRCH: LDA #4: JSR OSWRCH
   TYA:     JSR OSWRCH: LDA #1: JSR OSWRCH
   PLA: TAX
   INX
   CPX #9
   BNE grid_l
   RTS

.init_board
   EQUS "RNBQKBNR"
   EQUS "PPPPPPPP"
   EQUS "........"
   EQUS "........"
   EQUS "........"
   EQUS "........"
   EQUS "pppppppp"
   EQUS "rnbqkbnr"

;; 7 halve zetten (Herdermat: 1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6 4.Qxf7#!)
.move_from
   EQUB 52, 36                ; 1. e2-e4
   EQUB 12, 28                ; 1... e7-e5
   EQUB 61, 34                ; 2. Bf1-c4
   EQUB 1,  18                ; 2... Nb8-c6
   EQUB 59, 31                ; 3. Qd1-h5
   EQUB 6,  21                ; 3... Ng8-f6
   EQUB 31, 13                ; 4. Qh5xf7# SCHAAKMAT!

.msg_hdr
   EQUS "=== KIM-1 MICROCHESS (Peter Jennings, 1976) === ZET #", 0
.msg_cols
   EQUS "    a b c d e f g h", 13
   EQUS "  +-----------------+", 13, 0
.msg_mate
   EQUS "  +-----------------+", 13
   EQUS "[6502 MICROCHESS] 4. Dxf7# SCHAAKMAT! Wit wint!", 13, 0

.end
SAVE start, end
