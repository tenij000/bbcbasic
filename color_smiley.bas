10 REM Multi-Color Hardware Sprite Demo
20 MODE 0: CLG
30 PRINT "Laden van multi-color pixels in FPGA..."
40 DIM MC(255)
50 FOR I = 0 TO 255: READ MC(I): NEXT I
60 REM Wis sprite 0 en 1, en upload de meerkleurige smiley!
70 PLOT 200, 0, 0
80 FOR I=0 TO 255
90   PLOT 203, I, MC(I)
100 NEXT I
110 PLOT 200, 1, 0
120 FOR I=0 TO 255: PLOT 203, I, MC(I): NEXT I
130 PRINT "Klaar! Sprite 0 en 1 zijn nu meerkleurig."
140 DIM PX(1), PY(1), DX(1), DY(1)
150 FOR S = 0 TO 1
160   PX(S) = RND(1000) + 100
170   PY(S) = RND(800) + 100
180   DX(S) = 4 * SGN(RND(1) - 0.5)
190   DY(S) = 4 * SGN(RND(1) - 0.5)
200 NEXT S
210 REM Wis de andere 14 sprites om de boel overzichtelijk te houden
220 FOR S = 2 TO 15: PLOT 200, S, 0: PLOT 202, 0, 0: NEXT S
230 REM Teken een statisch SDRAM achtergrondje om transparantie te tonen
240 GCOL 0, 6 : GLINE 0, 500, 1279, 500
250 GCOL 0, 5 : GLINE 640, 0, 640, 1023
260 REM Hoofdlus
270 FOR S = 0 TO 1
280   PX(S) = PX(S) + DX(S)
290   PY(S) = PY(S) + DY(S)
300   IF PX(S) < 0 OR PX(S) > 1247 THEN DX(S) = -DX(S)
310   IF PY(S) < 0 OR PY(S) > 991 THEN DY(S) = -DY(S)
320   PLOT 200, S, 0
330   PLOT 201, PX(S), PY(S)
340 NEXT S
350 ?&A002 = 5 : REM Hardware Delay van 50ms (5 * 10ms)
360 GOTO 270
370 REM Multi-Color Graphic Data (0=Transparant, 1=Rood, 3=Geel, 4=Blauw)
380 DATA 0,0,0,0,3,3,3,3,3,3,3,3,0,0,0,0
390 DATA 0,0,3,3,3,3,3,3,3,3,3,3,3,3,0,0
400 DATA 0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0
410 DATA 0,3,3,3,4,4,3,3,3,3,4,4,3,3,3,0
420 DATA 3,3,3,3,4,4,3,3,3,3,4,4,3,3,3,3
430 DATA 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
440 DATA 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
450 DATA 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
460 DATA 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
470 DATA 3,3,1,3,3,3,3,3,3,3,3,3,3,1,3,3
480 DATA 0,3,1,1,3,3,3,3,3,3,3,3,1,1,3,0
490 DATA 0,3,3,1,1,1,1,1,1,1,1,1,1,3,3,0
500 DATA 0,0,3,3,3,1,1,1,1,1,1,3,3,3,0,0
510 DATA 0,0,0,0,3,3,3,3,3,3,3,3,0,0,0,0
520 DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
530 DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
