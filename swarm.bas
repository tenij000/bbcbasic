10 REM 16-Sprite Swarm Demo!
20 MODE 0
30 CLG
40 PRINT "Initialiseren van 16 Hardware Sprites..."
50 DIM x(15), y(15), dx(15), dy(15), c(15)
60 FOR i=0 TO 15
70   x(i) = RND(1000) + 100
80   y(i) = RND(800) + 100
90   dx(i) = (RND(4) + 2) * SGN(RND(1) - 0.5)
100  dy(i) = (RND(4) + 2) * SGN(RND(1) - 0.5)
110  c(i) = (i MOD 7) + 1
120  PLOT 200, i, 0
130  PLOT 201, x(i), y(i)
140 NEXT i
150 PRINT "Swarm actief!"
160 REM Hoofdlus
170 FOR i=0 TO 15
180   x(i) = x(i) + dx(i)
190   y(i) = y(i) + dy(i)
200   IF x(i) < 0 OR x(i) > 1247 THEN dx(i) = -dx(i)
210   IF y(i) < 0 OR y(i) > 991 THEN dy(i) = -dy(i)
220   PLOT 200, i, 0
230   PLOT 201, x(i), y(i)
240 NEXT i
250 GOTO 170
