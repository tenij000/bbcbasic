10 REM 16 Unieke Hardware Sprites Demo
20 MODE 0: CLG
30 PRINT "Genereren van 16 unieke retro patronen..."
40 FOR S = 0 TO 15
50   PRINT "Bewerken van Sprite "; S
60   PLOT 200, S, 0
70   C = (S MOD 7) + 1 : REM Geef elke sprite een unieke kleur
80   FOR Y = 0 TO 15
90     FOR X = 0 TO 15
100      ADDR = (Y * 16) + X
110      REM Klassieke bitwise 'demoscene' magie voor unieke vormen!
120      IF (X AND (S+1)) = (Y AND (S+1)) THEN PLOT 203, ADDR, C ELSE PLOT 203, ADDR, 0
130    NEXT X
140  NEXT Y
150 NEXT S
160 PRINT "Starten van de Zwerm!"
170 DIM PX(15), PY(15), DX(15), DY(15)
180 FOR S = 0 TO 15
190   PX(S) = RND(1000) + 100
200   PY(S) = RND(800) + 100
210   DX(S) = (RND(4) + 2) * SGN(RND(1) - 0.5)
220   DY(S) = (RND(4) + 2) * SGN(RND(1) - 0.5)
230 NEXT S
240 REM Hoofdlus
250 FOR S = 0 TO 15
260   PX(S) = PX(S) + DX(S)
270   PY(S) = PY(S) + DY(S)
280   IF PX(S) < 0 OR PX(S) > 1247 THEN DX(S) = -DX(S)
290   IF PY(S) < 0 OR PY(S) > 991 THEN DY(S) = -DY(S)
300   PLOT 200, S, 0
310   PLOT 201, PX(S), PY(S)
320 NEXT S
330 GOTO 250
