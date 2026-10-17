;; =============================================================
;; WOZMON6502.ASM — Steve Wozniak's Apple-1 System Monitor (1976)
;; Geport naar Tang Nano 20K 6502 + MiniGPU (ORG $6000)
;; Start vanaf Drive 1 met:
;;   *DRIVE 1
;;   *RUN WOZMON
;; =============================================================

OSRDCH   = $FFE0
OSASCI   = $FFE3
OSNEWL   = $FFE7
OSWRCH   = $FFEE
TIMER_10 = $A002

XAML     = $70                ; Laatst geopende adres (low)
XAMH     = $71                ; Laatst geopende adres (high)
STL      = $72                ; Store-adres (low)
STH      = $73                ; Store-adres (high)
L        = $74                ; Hex-parse waarde (low)
H        = $75                ; Hex-parse waarde (high)
YSAV     = $76                ; Tijdelijke Y-index
MODE     = $77                ; $00=XAM, $7F=STOR, $AE=BLOCK XAM

IN_BUF   = $0500              ; Apple-1 input buffer

ORG $6000

.start
   ; Wis tekst en grafisch scherm
   LDA #12: JSR OSWRCH
   LDA #16: JSR OSWRCH

   ; Teken een groene Apple-1 monitor-rand op de MiniGPU
   LDA #18: JSR OSWRCH: LDA #0: JSR OSWRCH: LDA #2: JSR OSWRCH
   LDA #25: JSR OSWRCH: LDA #4: JSR OSWRCH
   LDA #40: JSR OSWRCH: LDA #0: JSR OSWRCH
   LDA #40: JSR OSWRCH: LDA #0: JSR OSWRCH
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   LDA #$D8: JSR OSWRCH: LDA #$04: JSR OSWRCH
   LDA #40: JSR OSWRCH: LDA #0: JSR OSWRCH
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   LDA #$D8: JSR OSWRCH: LDA #$04: JSR OSWRCH
   LDA #$D8: JSR OSWRCH: LDA #$03: JSR OSWRCH
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   LDA #40: JSR OSWRCH: LDA #0: JSR OSWRCH
   LDA #$D8: JSR OSWRCH: LDA #$03: JSR OSWRCH
   LDA #25: JSR OSWRCH: LDA #5: JSR OSWRCH
   LDA #40: JSR OSWRCH: LDA #0: JSR OSWRCH
   LDA #40: JSR OSWRCH: LDA #0: JSR OSWRCH

   ; Zet tekstkleur op Apple-1 Fosfor Groen (VDU 17, 2)
   LDA #17: JSR OSWRCH: LDA #2: JSR OSWRCH
   LDX #0
.pr_banner
   LDA msg_banner,X
   BEQ demo_dump
   JSR OSASCI
   INX
   BNE pr_banner

.demo_dump
   ; Voer automatisch "6000.602F" uit via WozMon parser als start-demo!
   LDX #0
.copy_demo
   LDA demo_cmd,X
   STA IN_BUF,X
   CMP #$0D
   BEQ run_demo_cmd
   INX
   BNE copy_demo
.run_demo_cmd
   JMP parse_line

   ; Start de authentieke Wozniak Monitor Loop!
.escape
   LDA #'\'
   JSR OSASCI
.getline
   JSR OSNEWL
   LDA #'\'
   JSR OSASCI
   LDA #' '
   JSR OSASCI
   LDY #$00
.nextchar
   JSR OSRDCH
   CMP #$1B                   ; ESC -> Terug naar BBC BASIC!
   BEQ exit_wozmon
   CMP #'Q'
   BEQ exit_wozmon
   CMP #'q'
   BEQ exit_wozmon
   CMP #$08                   ; Backspace
   BEQ backspace
   CMP #'a'
   BCC not_lower
   CMP #'z'+1
   BCS not_lower
   AND #$DF                   ; Maak hoofdletter
.not_lower
   STA IN_BUF,Y
   JSR OSASCI
   CMP #$0D                   ; Enter?
   BEQ parse_line
   INY
   CPY #$40
   BCC nextchar
   BCS escape
.backspace
   CPY #$00
   BEQ nextchar
   DEY
   JMP nextchar

.exit_wozmon
   LDA #17: JSR OSWRCH: LDA #7: JSR OSWRCH
   JSR OSNEWL
   RTS

.parse_line
   LDY #$FF
   LDA #$00
   TAX
.setstor
   ASL A                      ; $7B<<1 = $F6 / $00
.setmode
   STA MODE
.blskip
   INY
.nextitem
   LDA IN_BUF,Y
   CMP #$0D
   BEQ getline
   CMP #'.'
   BCC blskip
   BEQ setmode                ; '.' = Block Examine ($2E)
   CMP #':'
   BEQ setstor                ; ':' = Store ($3A)
   CMP #'R'
   BEQ run_prog               ; 'R' = Run programma op (XAML:XAMH)
   STX L
   STX H
   STY YSAV
.nexthex
   LDA IN_BUF,Y
   EOR #$30
   CMP #$0A
   BCC dig
   ADC #$88
   CMP #$FA
   BCC nothex
.dig
   ASL A
   ASL A
   ASL A
   ASL A
   LDX #$04
.hexshift
   ASL A
   ROL L
   ROL H
   DEX
   BNE hexshift
   INY
   BNE nexthex
.nothex
   CPY YSAV
   BNE ok_hex
   JMP escape
.ok_hex
   BIT MODE
   BVC notstor
   ; STORE mode: schrijf byte L naar (STL:STH)
   LDA L
   STA (STL,X)
   INC STL
   BNE nextitem
   INC STH
   JMP nextitem

.run_prog
   JSR jmp_xam
   JMP getline
.jmp_xam
   JMP (XAML)

.notstor
   LDA MODE
   BNE xamnext
   ; Eerste adres: kopieer L/H naar STL/STH en XAML/XAMH
   LDX #$02
.setadr
   LDA L-1,X
   STA STL-1,X
   STA XAML-1,X
   DEX
   BNE setadr
   ; Print adres + byte
.nxtprnt
   BNE prdata
   JSR OSNEWL
   LDA XAMH
   JSR prbyte
   LDA XAML
   JSR prbyte
   LDA #':'
   JSR OSASCI
.prdata
   LDA #' '
   JSR OSASCI
   LDA (XAML,X)
   JSR prbyte
.xamnext
   STX MODE
   LDA XAML
   CMP L
   LDA XAMH
   SBC H
   BCS tonextitem
   INC XAML
   BNE mod8chk
   INC XAMH
.mod8chk
   LDA XAML
   AND #$07
   BPL nxtprnt
.tonextitem
   JMP nextitem

.prbyte
   PHA
   LSR A: LSR A: LSR A: LSR A
   JSR prhex
   PLA
.prhex
   AND #$0F
   ORA #$30
   CMP #$3A
   BCC echo_hex
   ADC #$06
.echo_hex
   JMP OSASCI

.demo_cmd
   EQUS "6000.602F", $0D

.msg_banner
   EQUS "=== APPLE-1 WOZ MONITOR (Steve Wozniak 1976) ===", 13
   EQUS "  6000.603F -> Hexdump | 3000: A9 42 60 -> Poke", 13
   EQUS "  3000R     -> Run ASM | Q of ESC       -> Stop", 13, 0

.end
SAVE start, end
