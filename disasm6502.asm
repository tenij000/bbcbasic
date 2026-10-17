;; =============================================================
;; DISASM6502.ASM — Wozniak & Baum 6502 Disassembler (1976)
;; Disassembleert live 6502 machinecode in RAM ($6000) & ROM ($B000)!
;; Start vanaf Drive 1 met:
;;   *DRIVE 1
;;   *RUN DISASM
;; =============================================================

OSASCI   = $FFE3
OSNEWL   = $FFE7
OSWRCH   = $FFEE

PC_LO    = $70
PC_HI    = $71
OPCODE   = $72
INST_LEN = $73
LINE_CNT = $74
TAB_IDX  = $75

ORG $6000

.start
   LDA #12: JSR OSWRCH
   LDA #16: JSR OSWRCH

   ; Titel in Geel (VDU 17, 3)
   LDA #17: JSR OSWRCH: LDA #3: JSR OSWRCH
   LDX #0
.pr_hdr
   LDA msg_title,X
   BEQ start_dis
   JSR OSASCI
   INX
   BNE pr_hdr

.start_dis
   ; Disassembleer 16 instructies vanaf $6000 (ons eigen programma in RAM!)
   LDA #$00: STA PC_LO
   LDA #$60: STA PC_HI
   LDA #16:  STA LINE_CNT

.dis_loop
   ; 1. Print PC adres in Groen ($XXXX: )
   LDA #17: JSR OSWRCH: LDA #2: JSR OSWRCH
   LDA #'$': JSR OSASCI
   LDA PC_HI: JSR pr_hex_byte
   LDA PC_LO: JSR pr_hex_byte
   LDA #':': JSR OSASCI
   LDA #' ': JSR OSASCI

   ; 2. Lees opcode en zoek op in op_table
   LDY #0
   LDA (PC_LO),Y
   STA OPCODE

   LDX #0
.lookup_loop
   LDA op_codes,X
   CMP #$FF
   BEQ unknown_op
   CMP OPCODE
   BEQ found_op
   INX
   BNE lookup_loop

.unknown_op
   STX TAB_IDX
   LDA #1: STA INST_LEN
   JMP print_raw_bytes

.found_op
   STX TAB_IDX
   LDA op_lens,X
   STA INST_LEN

.print_raw_bytes
   ; Print 1..3 hex bytes in Cyaan
   LDA #17: JSR OSWRCH: LDA #6: JSR OSWRCH
   LDY #0
.raw_loop
   CPY INST_LEN
   BCS pad_raw
   LDA (PC_LO),Y
   JSR pr_hex_byte
   LDA #' ': JSR OSASCI
   INY
   CPY #3
   BNE raw_loop
   BEQ print_mnem
.pad_raw
   LDA #' ': JSR OSASCI: JSR OSASCI: JSR OSASCI
   INY
   CPY #3
   BNE pad_raw

.print_mnem
   LDA #' ': JSR OSASCI
   ; Print 3-letter mnemonic in Wit
   LDA #17: JSR OSWRCH: LDA #7: JSR OSWRCH
   LDA TAB_IDX
   CMP #28
   BCS pr_db_mnem
   ASL A
   CLC: ADC TAB_IDX           ; * 3
   TAX
   LDA op_mnems,X:   JSR OSASCI
   LDA op_mnems+1,X: JSR OSASCI
   LDA op_mnems+2,X: JSR OSASCI
   JMP print_operand

.pr_db_mnem
   LDA #'E': JSR OSASCI
   LDA #'Q': JSR OSASCI
   LDA #'B': JSR OSASCI

.print_operand
   LDA #' ': JSR OSASCI
   LDA INST_LEN
   CMP #1
   BEQ next_inst
   CMP #2
   BEQ pr_op_2
   ; 3-byte instructie ($XXXX)
   LDA #'$': JSR OSASCI
   LDY #2: LDA (PC_LO),Y: JSR pr_hex_byte
   LDY #1: LDA (PC_LO),Y: JSR pr_hex_byte
   JMP next_inst

.pr_op_2
   LDA OPCODE
   AND #$0F
   CMP #$09                   ; Immediate (#$XX)?
   BEQ pr_imm
   LDA OPCODE
   CMP #$A2                   ; LDX #$XX
   BEQ pr_imm
   CMP #$A0                   ; LDY #$XX
   BEQ pr_imm
   CMP #$E0                   ; CPX #$XX
   BEQ pr_imm
   CMP #$C0                   ; CPY #$XX
   BEQ pr_imm
   ; Anders Zero-Page of Relative branch ($XX)
   LDA #'$': JSR OSASCI
   LDY #1: LDA (PC_LO),Y: JSR pr_hex_byte
   JMP next_inst

.pr_imm
   LDA #'#': JSR OSASCI
   LDA #'$': JSR OSASCI
   LDY #1: LDA (PC_LO),Y: JSR pr_hex_byte

.next_inst
   JSR OSNEWL
   ; Tel INST_LEN op bij PC_LO:PC_HI
   LDA PC_LO
   CLC: ADC INST_LEN
   STA PC_LO
   BCC no_pc_carry
   INC PC_HI
.no_pc_carry
   DEC LINE_CNT
   BEQ dis_done
   JMP dis_loop

.dis_done
   LDA #17: JSR OSWRCH: LDA #3: JSR OSWRCH
   LDX #0
.pr_done
   LDA msg_done,X
   BEQ exit_dis
   JSR OSASCI
   INX
   BNE pr_done
.exit_dis
   LDA #17: JSR OSWRCH: LDA #7: JSR OSWRCH
   RTS

.pr_hex_byte
   PHA
   LSR A: LSR A: LSR A: LSR A
   JSR pr_nib
   PLA
.pr_nib
   AND #$0F
   ORA #$30
   CMP #$3A
   BCC pr_nib_out
   ADC #$06
.pr_nib_out
   JMP OSASCI

;; Opcode tabel (28 veelgebruikte 6502 opcodes)
.op_codes
   EQUB $A9, $85, $8D, $AD, $A2, $A0, $20, $4C
   EQUB $60, $D0, $F0, $90, $B0, $C9, $E0, $C0
   EQUB $E8, $C8, $CA, $88, $18, $38, $69, $E9
   EQUB $29, $09, $48, $68, $FF

.op_lens
   EQUB 2, 2, 3, 3, 2, 2, 3, 3
   EQUB 1, 2, 2, 2, 2, 2, 2, 2
   EQUB 1, 1, 1, 1, 1, 1, 2, 2
   EQUB 2, 2, 1, 1

.op_mnems
   EQUS "LDASTASTALDALDXLDYJSRJMP"
   EQUS "RTSBNEBEQBCCBCSCMPCMPCPY"
   EQUS "INXINYDEXDEYCLCSECADCSBC"
   EQUS "ANDORAPHAPLA"

.msg_title
   EQUS "================================================", 13
   EQUS "  6502 DISASSEMBLER (Wozniak & Baum, 1976)      ", 13
   EQUS "  Live Disassembly van RAM ($6000 - $6024):     ", 13
   EQUS "================================================", 13, 0

.msg_done
   EQUS "------------------------------------------------", 13
   EQUS "[6502 DISASM] 16 instructies gedecodeerd!", 13, 0

.end
SAVE start, end
