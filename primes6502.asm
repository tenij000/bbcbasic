;; =============================================================
;; PRIMES6502.ASM — BYTE Magazine Sieve of Eratosthenes (1981)
;; Klassieke 6502 Priemgetallen-Benchmark + GPU Prime Visualizer!
;; Start vanaf Drive 1 met:
;;   *DRIVE 1
;;   *RUN PRIMES
;; =============================================================

OSASCI   = $FFE3
OSNEWL   = $FFE7
OSWRCH   = $FFEE

SIEVE    = $0400              ; 256 flags (1 = priem, 0 = samengesteld)
CUR_P    = $70
MULT     = $71
COUNT    = $72
COL_CNT  = $73
TEMP_N   = $74

ORG $6000

.start
   LDA #12: JSR OSWRCH
   LDA #16: JSR OSWRCH

   ; Titel in Geel (VDU 17, 3)
   LDA #17: JSR OSWRCH: LDA #3: JSR OSWRCH
   LDX #0
.pr_hdr
   LDA msg_hdr,X
   BEQ init_sieve
   JSR OSASCI
   INX
   BNE pr_hdr

.init_sieve
   ; Zet alle getallen 2..255 op 1 (potentieel priem)
   LDA #1
   LDX #2
.fill_loop
   STA SIEVE,X
   INX
   BNE fill_loop
   LDA #0
   STA SIEVE
   STA SIEVE+1

   ; Zeef van Eratosthenes voor p = 2..15
   LDA #2
   STA CUR_P
.sieve_outer
   LDX CUR_P
   LDA SIEVE,X
   BEQ next_p
   ; Streep alle veelvouden 2*p, 3*p, ... weg
   TXA
   ASL A
   BCS next_p
   STA MULT
.sieve_inner
   LDX MULT
   LDA #0
   STA SIEVE,X
   LDA MULT
   CLC
   ADC CUR_P
   BCS next_p
   STA MULT
   JMP sieve_inner

.next_p
   INC CUR_P
   LDA CUR_P
   CMP #16
   BCC sieve_outer

   ; Print alle gevonden priemgetallen (2..255) én teken ze op de GPU!
   LDA #0
   STA COUNT
   STA COL_CNT
   LDX #2
   STX CUR_P

.print_loop
   LDX CUR_P
   LDA SIEVE,X
   BEQ not_prime

   INC COUNT
   ; Kleur afwisselend Groen/Cyaan/Geel/Wit
   LDA #17: JSR OSWRCH
   LDA COUNT: AND #$03: CLC: ADC #2: JSR OSWRCH

   ; Print CUR_P als 3-cijferig decimaal getal
   LDA CUR_P
   JSR pr_dec8
   LDA #' ': JSR OSASCI

   ; Teken priem-balkje/cirkel op de 720p HDMI MiniGPU!
   JSR gpu_plot_prime

   INC COL_CNT
   LDA COL_CNT
   CMP #10
   BCC not_prime
   LDA #0: STA COL_CNT
   JSR OSNEWL

.not_prime
   INC CUR_P
   BNE print_loop

   JSR OSNEWL
   LDA #17: JSR OSWRCH: LDA #2: JSR OSWRCH
   LDX #0
.pr_done
   LDA msg_done,X
   BEQ pr_total
   JSR OSASCI
   INX
   BNE pr_done

.pr_total
   LDA COUNT
   JSR pr_dec8
   JSR OSNEWL
   LDA #17: JSR OSWRCH: LDA #7: JSR OSWRCH
   RTS

;; Print A (0..255) als 3 decimale cijfers
.pr_dec8
   STA TEMP_N
   LDY #'0'
.h_loop
   LDA TEMP_N
   CMP #100
   BCC h_done
   SEC: SBC #100
   STA TEMP_N
   INY
   BNE h_loop
.h_done
   TYA: JSR OSASCI
   LDY #'0'
.t_loop
   LDA TEMP_N
   CMP #10
   BCC t_done
   SEC: SBC #10
   STA TEMP_N
   INY
   BNE t_loop
.t_done
   TYA: JSR OSASCI
   LDA TEMP_N
   CLC: ADC #'0'
   JMP OSASCI

;; Teken priemgetal op de MiniGPU
.gpu_plot_prime
   LDA #18: JSR OSWRCH: LDA #0: JSR OSWRCH
   LDA COUNT: AND #$07: ORA #$01: JSR OSWRCH

   ; MOVE (CUR_P * 4 + 128, 300)
   LDA #25: JSR OSWRCH: LDA #4: JSR OSWRCH
   LDA CUR_P: ASL A: ASL A: JSR OSWRCH
   LDA #0: ADC #1: JSR OSWRCH
   LDA #$2C: JSR OSWRCH: LDA #$01: JSR OSWRCH

   ; CIRCLE straal = (CUR_P & 31) + 8
   LDA #25: JSR OSWRCH: LDA #199: JSR OSWRCH
   LDA CUR_P: AND #$1F: CLC: ADC #8: JSR OSWRCH
   LDA #0: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #0: JSR OSWRCH
   RTS

.msg_hdr
   EQUS "================================================", 13
   EQUS "  BYTE MAGAZINE SIEVE OF ERATOSTHENES (1981)    ", 13
   EQUS "  6502 Priemgetallen Benchmark (2 t/m 255):     ", 13
   EQUS "================================================", 13, 0

.msg_done
   EQUS "------------------------------------------------", 13
   EQUS "[6502 SIEVE] Aantal priemgetallen gevonden: ", 0

.end
SAVE start, end
