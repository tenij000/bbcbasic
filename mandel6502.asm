;; =============================================================
;; MANDEL6502.ASM — 6502 Fixed-Point Mandelbrot Fractal (1980s)
;; Puur 6502 Machinetaal op $6000 (3.5 Fixed-Point Math + GPU!)
;; Start vanaf Drive 1 met:
;;   *DRIVE 1
;;   *RUN MANDEL
;; =============================================================

OSASCI   = $FFE3
OSNEWL   = $FFE7
OSWRCH   = $FFEE

CR       = $70                ; C_real (signed 3.5 fixed point, 32 = 1.0)
CI       = $71                ; C_imag (signed 3.5 fixed point, 32 = 1.0)
ZR       = $72                ; Z_real
ZI       = $73                ; Z_imag
AZR      = $74                ; |Z_real|
AZI      = $75                ; |Z_imag|
ZR2      = $76                ; Z_real^2 >> 5
ZI2      = $77                ; Z_imag^2 >> 5
ITER     = $78                ; Iteratie-teller (0..14)
 SIGN_XOR = $79               ; Teken van ZR * ZI
MUL_A    = $7A
MUL_B    = $7B
PROD_LO  = $7C
PROD_HI  = $7D
COL_X    = $7E
ROW_Y    = $7F

ORG $6000

.start
   LDA #12: JSR OSWRCH
   LDA #16: JSR OSWRCH

   ; Titel in Cyaan
   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDX #0
.pr_title
   LDA msg_title,X
   BEQ mandel_begin
   JSR OSASCI
   INX
   BNE pr_title

.mandel_begin
   ; CI loopt van -36 (-1.125) t/m +36 (+1.125), stap +4 (19 rijen)
   LDA #256-36
   STA CI
   LDA #0
   STA ROW_Y

.row_loop
   ; CR loopt van -66 (-2.06) t/m +24 (+0.75), stap +2 (46 kolommen)
   LDA #256-66
   STA CR
   LDA #0
   STA COL_X

.col_loop
   LDA #0
   STA ZR
   STA ZI
   STA ITER

.iter_loop
   ; AZR = |ZR|
   LDA ZR
   BPL zr_pos
   EOR #$FF: CLC: ADC #1
.zr_pos
   CMP #64                    ; |ZR| >= 2.0?
   BCS escaped
   STA AZR

   ; AZI = |ZI|
   LDA ZI
   BPL zi_pos
   EOR #$FF: CLC: ADC #1
.zi_pos
   CMP #64                    ; |ZI| >= 2.0?
   BCS escaped
   STA AZI

   ; ZR2 = (AZR * AZR) >> 5
   LDA AZR: STA MUL_A: STA MUL_B
   JSR mul8x8_shr5
   STA ZR2

   ; ZI2 = (AZI * AZI) >> 5
   LDA AZI: STA MUL_A: STA MUL_B
   JSR mul8x8_shr5
   STA ZI2

   ; Als ZR2 + ZI2 >= 128 (4.0), dan ontsnapt!
   CLC
   ADC ZR2
   BMI escaped

   ; Bereken 2 * ZR * ZI >> 5 = (AZR * AZI) >> 4 met teken (ZR EOR ZI)
   LDA ZR: EOR ZI: STA SIGN_XOR
   LDA AZR: STA MUL_A
   LDA AZI: STA MUL_B
   JSR mul8x8_shr5
   ASL A                      ; >> 4 in plaats van >> 5 (is * 2)
   BIT SIGN_XOR
   BPL zri_pos
   EOR #$FF: CLC: ADC #1
.zri_pos
   CLC
   ADC CI
   PHA                        ; Nieuwe ZI op stack

   ; Nieuwe ZR = ZR2 - ZI2 + CR
   LDA ZR2
   SEC
   SBC ZI2
   CLC
   ADC CR
   STA ZR

   PLA
   STA ZI

   INC ITER
   LDA ITER
   CMP #14
   BCC iter_loop

.escaped
   ; Kies kleur en ASCII-teken op basis van ITER (0..14)
   LDX ITER
   LDA iter_col,X
   PHA
   LDA #17: JSR OSWRCH
   PLA: JSR OSWRCH

   LDX ITER
   LDA iter_chr,X
   JSR OSASCI

   ; Teken ook op de 720p HDMI GPU als het punt binnen de rand ligt (ITER > 1)
   LDX ITER
   CPX #2
   BCC next_pixel
   JSR plot_gpu_mandel

.next_pixel
   LDA CR
   CLC
   ADC #2
   STA CR
   INC COL_X
   LDA COL_X
   CMP #46
   BCS row_done
   JMP col_loop
.row_done

   JSR OSNEWL
   LDA CI
   CLC
   ADC #4
   STA CI
   INC ROW_Y
   LDA ROW_Y
   CMP #19
   BCC jmp_row_loop

   ; Klaar! Zet tekstkleur terug op Wit (7)
   LDA #17: JSR OSWRCH: LDA #7: JSR OSWRCH
   LDX #0
.pr_ftr
   LDA msg_done,X
   BEQ exit_mandel
   JSR OSASCI
   INX
   BNE pr_ftr
.exit_mandel
   RTS

.jmp_row_loop
   JMP row_loop

;; 8x8 unsigned vermenigvuldiging (MUL_A * MUL_B) >> 5 -> resultaat in A
.mul8x8_shr5
   LDA #0
   STA PROD_HI
   LDX #8
.mul_loop
   LSR MUL_B
   BCC mul_no_add
   CLC
   ADC MUL_A
.mul_no_add
   ROR A
   ROR PROD_HI
   DEX
   BNE mul_loop
   ; Nu staat 16-bit product in A (high byte) en PROD_HI (low byte)
   ; Deel door 32 (>> 5) = neem bits [12:5] -> links schuiven met 3 bits!
   ASL PROD_HI: ROL A
   ASL PROD_HI: ROL A
   ASL PROD_HI: ROL A
   RTS

;; Plot gekleurd blokje op de MiniGPU voor (COL_X, ROW_Y)
.plot_gpu_mandel
   LDX ITER
   LDA #18: JSR OSWRCH
   LDA #0:  JSR OSWRCH
   LDA iter_col,X: JSR OSWRCH

   ; X = 256 + COL_X * 16
   LDA COL_X
   ASL A: ASL A: ASL A: ASL A
   PHA
   LDA #0
   ADC #1
   TAX                        ; X = high byte, stack = low byte

   ; Y = 180 + (18 - ROW_Y) * 32
   LDA #18
   SEC: SBC ROW_Y
   ASL A: ASL A: ASL A: ASL A: ASL A
   TAY                        ; Y = low byte van Y (high byte = 1)

   ; MOVE X, Y (PLOT 4)
   LDA #25: JSR OSWRCH
   LDA #4:  JSR OSWRCH
   PLA:     PHA: JSR OSWRCH
   TXA:     JSR OSWRCH
   TYA:     JSR OSWRCH
   LDA #1:  JSR OSWRCH

   ; DRAW X+10, Y (PLOT 5)
   LDA #25: JSR OSWRCH
   LDA #5:  JSR OSWRCH
   PLA: CLC: ADC #10: JSR OSWRCH
   TXA: ADC #0: JSR OSWRCH
   TYA: JSR OSWRCH
   LDA #1: JSR OSWRCH
   RTS

.iter_chr
   EQUS " .,:;+*%#@#%*+ "
.iter_col
   EQUB 4, 4, 6, 6, 2, 2, 3, 3, 1, 1, 5, 5, 7, 7, 0

.msg_title
   EQUS "=== 6502 MANDELBROT FRACTAL (Z = Z^2 + C) ===", 13, 0

.msg_done
   EQUS "[6502 MANDEL] 874 complexe punten berekend in pure 6502 ASM!", 13, 0

.end
SAVE start, end
