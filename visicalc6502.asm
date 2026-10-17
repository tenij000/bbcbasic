;; =============================================================
;; VISICALC6502.ASM — "Mini-VisiCalc / Excel 6502" (ORG $6000)
;; 100% Pure 6502 Machinetaal Spreadsheet voor Tang Nano 20K!
;; Start vanaf SD-kaart of 4 MB SDRAM-Disk met:
;;   *RUN EXCEL
;;
;; Besturing (PS/2 Toetsenbord of Terminal):
;;   W / A / S / D : Verplaats cel-cursor (Kolom A..D, Rij 1..6)
;;   0..9 + ENTER  : Typ een nieuw getal (0..255) in de huidige cel
;;   + / -         : Verhoog / verlaag huidige cel met 1
;;   F             : Vul met demo-cijfers
;;   C             : Wis alle cellen (0)
;;   Q             : Afsluiten terug naar de > prompt (RTS)
;; =============================================================

OSRDCH   = $FFE0
OSWRCH   = $FFEE
GPU_PORT = $A001

;; Zero-Page variabelen ($70 - $7F, vrij tijdens 6502 binary run)
cur_col  = $70          ; Huidige kolom (0..3 = A..D)
cur_row  = $71          ; Huidige rij   (0..5 = Rij 1..6)
tmp_col  = $72
tmp_row  = $73
sum_lo   = $74          ; 16-bit opteller voor rij/kolom-som
sum_hi   = $75
num_lo   = $76          ; 16-bit getal voor 16-bit decimaal afdrukken
num_hi   = $77
inp_val  = $78          ; Invoer-accumulator tijdens getal typen
inp_act  = $79          ; 1 als gebruiker cijfers aan het typen is
ptr_lo   = $7A
ptr_hi   = $7B

ORG $6000

.start
   LDA #$00
   STA cur_col
   STA cur_row
   STA inp_val
   STA inp_act
   JSR load_demo_data

   ; Wis scherm eenmalig en teken gekleurd GPU-kader
   LDA #12: JSR OSWRCH
   LDA #16: STA GPU_PORT

.main_loop
   JSR draw_sheet
   JSR draw_chart

   ; Lees toets van PS/2 toetsenbord (OSRDCH $FFE0)
   JSR OSRDCH
   CMP #$1B                  ; ESC?
   BNE not_esc
   JMP quit_prog
.not_esc
   ; Check cijfers '0'..'9'
   CMP #'0'
   BCC not_digit
   CMP #'9'+1
   BCS not_digit
   SEC
   SBC #'0'
   PHA
   LDA inp_act
   BNE append_digit
   LDA #$01
   STA inp_act
   PLA
   STA inp_val
   JMP store_inp_to_cell
.append_digit
   ; inp_val = inp_val * 10 + nieuwe cijfer
   LDA inp_val
   ASL A                     ; *2
   STA num_lo
   ASL A                     ; *4
   ASL A                     ; *8
   CLC
   ADC num_lo                ; *10
   STA inp_val
   PLA
   CLC
   ADC inp_val
   STA inp_val
.store_inp_to_cell
   JSR get_cur_cell_idx
   LDA inp_val
   STA cells,X
   JMP main_loop

.not_digit
   CMP #$0D                  ; ENTER bevestigt invoer
   BNE not_enter
   LDA #$00
   STA inp_act
   STA inp_val
   JMP main_loop

.not_enter
   CMP #'+'
   BNE not_plus
   LDA #$00: STA inp_act
   JSR get_cur_cell_idx
   INC cells,X
   JMP main_loop

.not_plus
   CMP #'='                  ; '=' werkt ook als '+'
   BNE not_eq
   LDA #$00: STA inp_act
   JSR get_cur_cell_idx
   INC cells,X
   JMP main_loop

.not_eq
   CMP #'-'
   BNE not_minus
   LDA #$00: STA inp_act
   JSR get_cur_cell_idx
   DEC cells,X
   JMP main_loop

.not_minus
   ; Converteer kleine letters naar hoofdletters
   AND #$DF
   PHA
   LDA #$00: STA inp_act     ; Reset cijfer-invoer bij navigatie
   PLA

   CMP #'Q'
   BEQ quit_prog
   CMP #'W'
   BEQ move_up
   CMP #'S'
   BEQ move_down
   CMP #'A'
   BEQ move_left
   CMP #'D'
   BEQ move_right
   CMP #'C'
   BEQ clear_all
   CMP #'F'
   BEQ fill_demo
   JMP main_loop

.move_up
   LDA cur_row
   BEQ go_main
   DEC cur_row
.go_main
   JMP main_loop

.move_down
   LDA cur_row
   CMP #$05
   BCS go_main
   INC cur_row
   JMP main_loop

.move_left
   LDA cur_col
   BEQ go_main
   DEC cur_col
   JMP main_loop

.move_right
   LDA cur_col
   CMP #$03
   BCS go_main
   INC cur_col
   JMP main_loop

.clear_all
   LDX #23
   LDA #$00
.clr_lp
   STA cells,X
   DEX
   BPL clr_lp
   JMP main_loop

.fill_demo
   JSR load_demo_data
   JMP main_loop

.quit_prog
   LDA #17: JSR OSWRCH
   LDA #7:  JSR OSWRCH
   LDA #31: JSR OSWRCH
   LDA #0:  JSR OSWRCH
   LDA #24: JSR OSWRCH
   LDX #<msg_bye
   LDY #>msg_bye
   JSR print_str
   RTS

;; -------------------------------------------------------------
;; Bereken X = cur_row * 4 + cur_col (0..23)
;; -------------------------------------------------------------
.get_cur_cell_idx
   LDA cur_row
   ASL A
   ASL A
   CLC
   ADC cur_col
   TAX
   RTS

;; -------------------------------------------------------------
;; Vul de 24 cellen met start-data
;; -------------------------------------------------------------
.load_demo_data
   LDX #23
.ld_demo_lp
   LDA demo_cells,X
   STA cells,X
   DEX
   BPL ld_demo_lp
   RTS

;; -------------------------------------------------------------
;; Teken het volledige Spreadsheet op het scherm (via VDU 31 TAB)
;; -------------------------------------------------------------
.draw_sheet
   ; Zet cursor linksboven: VDU 31, 0, 0
   LDA #31: JSR OSWRCH
   LDA #0:  JSR OSWRCH
   LDA #0:  JSR OSWRCH

   ; Titelbalk in Geel (COLOUR 3)
   LDA #17: JSR OSWRCH
   LDA #3:  JSR OSWRCH
   LDX #<msg_hdr
   LDY #>msg_hdr
   JSR print_str

   ; Kolomkoppen in Cyaan (COLOUR 6)
   LDA #17: JSR OSWRCH
   LDA #6:  JSR OSWRCH
   LDX #<msg_cols
   LDY #>msg_cols
   JSR print_str

   ; Loop over rijen 0..5
   LDA #$00
   STA tmp_row
.row_loop
   ; Print " RIJ x |" in Cyaan
   LDA #17: JSR OSWRCH
   LDA #6:  JSR OSWRCH
   LDA #' ': JSR OSWRCH
   LDA #'R': JSR OSWRCH
   LDA #'I': JSR OSWRCH
   LDA #'J': JSR OSWRCH
   LDA #' ': JSR OSWRCH
   LDA tmp_row
   CLC
   ADC #'1'
   JSR OSWRCH
   LDA #' ': JSR OSWRCH
   LDA #'|': JSR OSWRCH

   ; Reset rij-som (sum_hi:sum_lo = 0)
   LDA #$00
   STA sum_lo
   STA sum_hi
   STA tmp_col

.col_loop
   LDA #' ': JSR OSWRCH
   ; Check of (tmp_row == cur_row && tmp_col == cur_col)
   LDA tmp_row
   CMP cur_row
   BNE cell_not_sel
   LDA tmp_col
   CMP cur_col
   BNE cell_not_sel

   ; Geselecteerde cel: Groen (COLOUR 2) met "[>" en "]"
   LDA #17: JSR OSWRCH
   LDA #2:  JSR OSWRCH
   LDA #'[': JSR OSWRCH
   LDA #'>': JSR OSWRCH
   JMP print_cell_val

.cell_not_sel
   ; Normale cel: Wit (COLOUR 7) met "  "
   LDA #17: JSR OSWRCH
   LDA #7:  JSR OSWRCH
   LDA #' ': JSR OSWRCH
   LDA #' ': JSR OSWRCH

.print_cell_val
   ; Haal celwaarde op: index = tmp_row * 4 + tmp_col
   LDA tmp_row
   ASL A
   ASL A
   CLC
   ADC tmp_col
   TAX
   LDA cells,X
   STA num_lo
   LDA #$00
   STA num_hi

   ; Tel op bij rij-som
   CLC
   LDA sum_lo
   ADC num_lo
   STA sum_lo
   BCC no_sc
   INC sum_hi
.no_sc
   JSR print_num_4d

   ; Sluit cel af met ']' (als geselecteerd) of ' '
   LDA tmp_row
   CMP cur_row
   BNE cell_end_sp
   LDA tmp_col
   CMP cur_col
   BNE cell_end_sp
   LDA #']': JSR OSWRCH
   JMP next_col
.cell_end_sp
   LDA #' ': JSR OSWRCH

.next_col
   INC tmp_col
   LDA tmp_col
   CMP #$04
   BCC col_loop

   ; Print "| " en de automatische RIJ-SOM in Geel (COLOUR 3)
   LDA #17: JSR OSWRCH
   LDA #6:  JSR OSWRCH
   LDA #'|': JSR OSWRCH
   LDA #' ': JSR OSWRCH
   LDA #17: JSR OSWRCH
   LDA #3:  JSR OSWRCH
   LDA sum_lo: STA num_lo
   LDA sum_hi: STA num_hi
   JSR print_num_4d
   JSR send_crlf

   INC tmp_row
   LDA tmp_row
   CMP #$06
   BCS rows_done
   JMP row_loop
.rows_done

   ; Print scheidingslijn
   LDA #17: JSR OSWRCH
   LDA #6:  JSR OSWRCH
   LDX #<msg_sep
   LDY #>msg_sep
   JSR print_str

   ; Bereken en print KOLOM-TOTALEN (onderste rij)
   LDA #17: JSR OSWRCH
   LDA #3:  JSR OSWRCH
   LDX #<msg_tot_lbl
   LDY #>msg_tot_lbl
   JSR print_str

   LDA #$00
   STA tmp_col
   STA col_grand_lo
   STA col_grand_hi

.tot_col_loop
   LDA #$00
   STA sum_lo
   STA sum_hi
   STA tmp_row
.tot_row_loop
   LDA tmp_row
   ASL A
   ASL A
   CLC
   ADC tmp_col
   TAX
   CLC
   LDA sum_lo
   ADC cells,X
   STA sum_lo
   BCC tot_no_c
   INC sum_hi
.tot_no_c
   INC tmp_row
   LDA tmp_row
   CMP #$06
   BCC tot_row_loop

   ; Tel kolom-totaal op bij eindtotaal
   CLC
   LDA col_grand_lo
   ADC sum_lo
   STA col_grand_lo
   LDA col_grand_hi
   ADC sum_hi
   STA col_grand_hi

   LDA #' ': JSR OSWRCH
   LDA #' ': JSR OSWRCH
   LDA #' ': JSR OSWRCH
   LDA sum_lo: STA num_lo
   LDA sum_hi: STA num_hi
   JSR print_num_4d
   LDA #' ': JSR OSWRCH

   INC tmp_col
   LDA tmp_col
   CMP #$04
   BCC tot_col_loop

   ; Print Eindtotaal rechtsonder in Groen (COLOUR 2)
   LDA #'|': JSR OSWRCH
   LDA #' ': JSR OSWRCH
   LDA #17: JSR OSWRCH
   LDA #2:  JSR OSWRCH
   LDA col_grand_lo: STA num_lo
   LDA col_grand_hi: STA num_hi
   JSR print_num_4d
   JSR send_crlf

   ; Print statusbalk met geselecteerde cel (bijv. A1..D6) en instructies
   LDA #17: JSR OSWRCH
   LDA #7:  JSR OSWRCH
   LDX #<msg_help
   LDY #>msg_help
   JSR print_str

   ; Print huidige cel-coördinaat (A..D, 1..6) in Groen
   LDA #17: JSR OSWRCH
   LDA #2:  JSR OSWRCH
   LDA cur_col
   CLC
   ADC #'A'
   JSR OSWRCH
   LDA cur_row
   CLC
   ADC #'1'
   JSR OSWRCH
   LDA #' ': JSR OSWRCH
   LDA #'=': JSR OSWRCH
   LDA #' ': JSR OSWRCH
   JSR get_cur_cell_idx
   LDA cells,X: STA num_lo
   LDA #$00:    STA num_hi
   JSR print_num_4d
   JSR send_crlf
   RTS

;; -------------------------------------------------------------
;; Teken een live 2D Cirkel-Diagram van Kolom A..D via GPU ($A001)
;; -------------------------------------------------------------
.draw_chart
   ; Wis onderste grafische helft niet elke toets, maar teken 4 cirkels op Y=540 ($021C)
   LDX #$00
.chart_loop
   ; Kleur = X + 1 (Rood, Groen, Geel, Blauw)
   LDA #18: STA GPU_PORT
   LDA #0:  STA GPU_PORT
   TXA: CLC: ADC #1: STA GPU_PORT

   ; MOVE naar X = 250 + X*200, Y = 540 ($021C)
   LDA #25: STA GPU_PORT
   LDA #4:  STA GPU_PORT
   LDA chart_x_lo,X: STA GPU_PORT
   LDA chart_x_hi,X: STA GPU_PORT
   LDA #$1C: STA GPU_PORT
   LDA #$02: STA GPU_PORT

   ; Straal = waarde van Rij 1, Kolom X (begrensd op 10..90)
   LDA cells,X
   LSR A
   CLC
   ADC #10
   CMP #90
   BCC rad_ok
   LDA #90
.rad_ok
   PHA
   LDA #25:  STA GPU_PORT
   LDA #199: STA GPU_PORT
   PLA:      STA GPU_PORT
   LDA #0:   STA GPU_PORT
   LDA #0:   STA GPU_PORT
   LDA #0:   STA GPU_PORT

   INX
   CPX #$04
   BCC chart_loop
   RTS

;; -------------------------------------------------------------
;; Print 16-bit getal in (num_hi:num_lo) rechts-uitgelijnd (4 tekens)
;; -------------------------------------------------------------
.print_num_4d
   LDY #$00                  ; leading-zero vlag (0 = nog geen cijfer geprint)
   LDX #$00                  ; tabel-index (0=1000, 1=100, 2=10)
.dec_loop
   LDA #$00                  ; cijfer-teller
   PHA
.sub_loop
   LDA num_lo
   SEC
   SBC pow10_lo,X
   TAY
   LDA num_hi
   SBC pow10_hi,X
   BCC sub_done
   STA num_hi
   STY num_lo
   PLA
   CLC
   ADC #$01
   PHA
   JMP sub_loop
.sub_done
   PLA
   BNE got_nonzero
   CPX #$03
   BEQ print_zero_anyway
   LDA leading_flag
   BNE print_zero_anyway
   LDA #' '
   JSR OSWRCH
   JMP next_pow10
.got_nonzero
   pha
   LDA #$01
   STA leading_flag
   pla
.print_zero_anyway
   CLC
   ADC #'0'
   JSR OSWRCH
.next_pow10
   INX
   CPX #$03
   BCC dec_loop

   ; Laatste cijfer (eenheden 0..9) altijd printen
   LDA #$00
   STA leading_flag
   LDA num_lo
   CLC
   ADC #'0'
   JMP OSWRCH

.send_crlf
   LDA #13: JSR OSWRCH
   LDA #10: JMP OSWRCH

.print_str
   STX ptr_lo
   STY ptr_hi
   LDY #$00
.ps_lp
   LDA (ptr_lo),Y
   BEQ ps_done
   JSR OSWRCH
   INY
   BNE ps_lp
   INC ptr_hi
   JMP ps_lp
.ps_done
   RTS

;; -------------------------------------------------------------
;; Tabellen & Teksten
;; -------------------------------------------------------------
.leading_flag
   EQUB 0
.col_grand_lo
   EQUB 0
.col_grand_hi
   EQUB 0

.pow10_lo
   EQUB <1000, <100, <10
.pow10_hi
   EQUB >1000, >100, >10

.chart_x_lo
   EQUB <260, <480, <700, <920
.chart_x_hi
   EQUB >260, >480, >700, >920

.demo_cells
   EQUB  25,  40,  15,  20
   EQUB  10,  35,  50,  30
   EQUB  45,  20,  25,  60
   EQUB  30,  15,  40,  10
   EQUB  50,  60,  30,  40
   EQUB  20,  10,  35,  25

.cells
   SKIP 24

.msg_hdr
   EQUS "==============================================", 13, 10
   EQUS "   VISICALC / MINI-EXCEL 6502 (PURE ASM!)     ", 13, 10
   EQUS "==============================================", 13, 10, 0

.msg_cols
   EQUS "       |   KOL A   KOL B   KOL C   KOL D|  RIJ-SOM", 13, 10
   EQUS "-------+--------------------------------+---------", 13, 10, 0

.msg_sep
   EQUS "-------+--------------------------------+---------", 13, 10, 0

.msg_tot_lbl
   EQUS " TOTAAL|", 0

.msg_help
   EQUB 13, 10
   EQUS "[W/A/S/D]=Verplaats  [0-9+Enter]=Getal  [+/-]=Aanpassen", 13, 10
   EQUS "[C]=Wis blad  [F]=Demo-data  [Q]=Stop   Actieve Cel: ", 0

.msg_bye
   EQUB 13, 10
   EQUS "Mini-VisiCalc 6502 afgesloten. Tot ziens!", 13, 10, 0

.end
SAVE start, end
