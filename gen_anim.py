import os

f1 = [
    0x0180, 0x07E0, 0x1FF8, 0x3DB8,
    0x3FF8, 0x07E0, 0x0DB0, 0x1008,
    0, 0, 0, 0, 0, 0, 0, 0
]

f2 = [
    0x0180, 0x07E0, 0x1FF8, 0x3DB8,
    0x3FF8, 0x17E8, 0x2004, 0x0000,
    0, 0, 0, 0, 0, 0, 0, 0
]

def to_data(hex_list, start_line):
    lines = []
    line_num = start_line
    for h in hex_list:
        bits = [1 if (h & (1 << (15-b))) else 0 for b in range(16)]
        lines.append(f"{line_num} DATA " + ",".join(map(str, bits)))
        line_num += 10
    return lines, line_num

bas_lines = [
    "10 REM Space Invader Animatie Demo",
    "20 MODE 0: CLG",
    "30 PRINT \"Laden van graphics in FPGA RAM...\"",
    "40 DIM S1(255), S2(255)",
    "50 FOR I = 0 TO 255: READ S1(I): NEXT I",
    "60 FOR I = 0 TO 255: READ S2(I): NEXT I",
    "70 REM Wis sprite 0 en 1",
    "80 FOR S=0 TO 1",
    "90   PLOT 200, S, 0",
    "100  FOR I=0 TO 255: PLOT 203, I, 0: NEXT I",
    "110 NEXT S",
    "120 PRINT \"Uploaden Frame 1 (Groen)...\"",
    "130 PLOT 200, 0, 0",
    "140 FOR I=0 TO 255",
    "150   IF S1(I) = 1 THEN PLOT 203, I, 2 ELSE PLOT 203, I, 0",
    "160 NEXT I",
    "170 PRINT \"Uploaden Frame 2 (Rood)...\"",
    "180 PLOT 200, 1, 0",
    "190 FOR I=0 TO 255",
    "200   IF S2(I) = 1 THEN PLOT 203, I, 1 ELSE PLOT 203, I, 0",
    "210 NEXT I",
    "220 PRINT \"Animatie starten!\"",
    "230 X = 100: Y = 500: DX = 5",
    "240 REM Hoofdlus",
    "250 X = X + DX",
    "260 IF X < 0 OR X > 1200 THEN DX = -DX",
    "270 F = (X DIV 20) MOD 2",
    "280 IF F=0 THEN PLOT 200, 1, 0: PLOT 202, 0, 0: PLOT 200, 0, 0: PLOT 201, X, Y",
    "290 IF F=1 THEN PLOT 200, 0, 0: PLOT 202, 0, 0: PLOT 200, 1, 0: PLOT 201, X, Y",
    "300 GOTO 250",
    "310 REM Frame 1 Data"
]

dl1, ln = to_data(f1, 320)
bas_lines.extend(dl1)
bas_lines.append(f"{ln} REM Frame 2 Data")
dl2, ln = to_data(f2, ln+10)
bas_lines.extend(dl2)

with open("invader_anim.bas", "w") as f:
    f.write("\n".join(bas_lines) + "\n")
