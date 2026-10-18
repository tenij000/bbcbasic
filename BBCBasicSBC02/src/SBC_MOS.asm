;; *************************************************************
;; OS Interface Jump Table & 6502 Hardware Vectors ($FFCE-$FFFF)
;; *************************************************************

.do_point
   LDA #25: JSR OSWRCH
   LDA #222: JSR OSWRCH
   LDX #0
.pt_send_lp
   LDA &2A,X: JSR OSWRCH
   INX
   CPX #4
   BNE pt_send_lp
   LDA $A02B
   JMP LAED8

.reset_msg
   EQUB $0D
   EQUS "SBC02 SD-MOS 1.70 / BBC BASIC"
   EQUB $0A, $0D, $11, $00

.default_brk_handler
.reset_handler
{
   CLD
   LDX #$FF
   TXS
   LDA #<default_brk_handler
   STA BRKV
   LDA #>default_brk_handler
   STA BRKV + 1
   INX
   STX f_mode
   STX f_sdram
   STX f_drive
   STX bg_mode
   STX usr_bgv
   STX usr_bgv+1
   LDY #ZP_END - ZP_START + 1
.clrloop
   STX ZP_START - 1, Y
   DEY
   BNE clrloop
   LDA #<reset_msg
   STA ZP_ERRPTR
   LDA #>reset_msg
   STA ZP_ERRPTR + 1
   LDA #$95
   STA UART
   CLI
.prloop
   LDA reset_msg, Y
   BEQ done
   JSR OSASCI
   INY
   BNE prloop
.done
   JMP ENTER_BASIC
}

   ORG $ffce
.OSFIND
   JMP nvosfind
.OSGBPB
   JMP nvosgbpb
.OSBPUT
   JMP nvosbput
.OSBGET
   JMP nvosbget
.OSARGS
   JMP nvosargs
.OSFILE
   JMP nvosfile
.OSRDCH
   JMP nvosrdch
.OSASCI
   CMP #$0D
   BNE OSWRCH
.OSNEWL
   LDA #$0A
   JSR OSWRCH
   LDA #$0D
.OSWRCH
   JMP nvoswrch
.OSWORD
   JMP nvosword
.OSBYTE
   JMP nvosbyte
.OSCLI
   JMP nvoscli

;; *************************************************************
;; Vectors ($FFFA-$FFFF)
;; *************************************************************

   EQUW nmi_handler
   EQUW reset_handler
   EQUW irqbrk_handler
