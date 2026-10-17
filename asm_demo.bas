10 CLS
20 CLG
30 PRINT "=== 6502 MACHINETAAL (ASSEMBLY) DEMO ==="
40 PRINT "CPU: Arlet 6502 Core @ 27.000 MHz"
50 PRINT "Nu assembleren we echte 6502-code in RAM..."
60 DIM code% 256
70 FOR pass%=0 TO 2 STEP 2
80 P%=code%
90 [OPT pass%
100 .start_asm
110 LDX #0
120 .tekst_loop
130 LDA bericht,X
140 BEQ teken_start
150 JSR &FFEE
160 INX
170 BNE tekst_loop
180 .teken_start
190 LDY #10
200 .cirkel_loop
210 LDA #18  : STA &A001
220 LDA #0   : STA &A001
230 TYA      : STA &A001
240 LDA #25  : STA &A001
250 LDA #4   : STA &A001
260 LDA #&80 : STA &A001
270 LDA #&02 : STA &A001
280 LDA #&68 : STA &A001
290 LDA #&01 : STA &A001
300 LDA #25  : STA &A001
310 LDA #199 : STA &A001
320 TYA      : STA &A001
330 LDA #0   : STA &A001
340 LDA #0   : STA &A001
350 LDA #0   : STA &A001
360 INY : INY : INY : INY
370 CPY #250
380 BCC cirkel_loop
390 RTS
400 .bericht
410 EQUS ">> Groeten uit 27 MHz 6502 Machinetaal! <<"
420 EQUB 13
430 EQUB 10
440 EQUB 0
450 ]
460 NEXT pass%
470 PRINT ""
480 PRINT "Starten van 6502 machinecode met CALL..."
490 CALL start_asm
500 PRINT "Klaar! 60 cirkels rechtstreeks vanuit"
510 PRINT "6502 machinetaal naar GPU (&A001)!"
