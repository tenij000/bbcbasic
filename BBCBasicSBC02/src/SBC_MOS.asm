;; *************************************************************
;; OS Interface Jump Table & 6502 Hardware Vectors ($FFCE-$FFFF)
;; *************************************************************

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
