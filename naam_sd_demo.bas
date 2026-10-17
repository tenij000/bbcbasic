10 REM *** NAAM OPSLAAN & LADEN MET OPENOUT / OPENIN ***
20 CLS: CLG
30 GCOL 0, 14: RECT 300, 150, 680, 420
40 GCOL 0, 11: CIRCLE 640, 360, 160
50 PRINT "=========================================="
60 PRINT "   6502 SD-MOS: OPENOUT & OPENIN DEMO!   "
70 PRINT "=========================================="
80 PRINT ""
90 INPUT "HOE HEET JE? ", NAAM$
100 PRINT ""
110 PRINT "1) Bestand NAAM.DAT openen met OPENOUT..."
120 F% = OPENOUT("NAAM.DAT")
130 PRINT#F%, NAAM$
140 CLOSE#F%
150 PRINT "2) Naam is opgeslagen op de SD-kaart!"
160 NAAM$ = ""
170 PRINT "3) Nu teruglezen met OPENIN..."
180 F% = OPENIN("NAAM.DAT")
190 INPUT#F%, GELEZEN$
200 CLOSE#F%
210 PRINT ""
220 PRINT "=========================================="
230 PRINT " WELKOM TERUG VANAF SD-KAART, "; GELEZEN$; "!"
240 PRINT "=========================================="
