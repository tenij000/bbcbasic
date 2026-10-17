import os

smiley = [
    0x0000, 0x0FF0, 0x300C, 0x4662,
    0x8661, 0x8001, 0x8001, 0x8811,
    0x8421, 0x83C1, 0x4002, 0x300C,
    0x0FF0, 0x0000, 0x0000, 0x0000
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
    "10 REM Smiley Swarm Demo",
    "20 MODE 0: CLG",
    "30 PRINT \"Laden van Smiley graphics in FPGA...\"",
    "40 DIM SM(255)",
    "50 FOR I = 0 TO 255: READ SM(I): NEXT I",
    "60 REM Wis en upload de smiley naar alle 16 sprites!",
    "70 FOR S=0 TO 15",
    "80   PLOT 200, S, 0",
    "90   C = (S MOD 7) + 1 : REM Geef elke smiley een eigen kleur",
    "100  FOR I=0 TO 255",
    "110    IF SM(I) = 1 THEN PLOT 203, I, C ELSE PLOT 203, I, 0",
    "120  NEXT I",
    "130 NEXT S",
    "140 PRINT \"Daar gaan de smileys!\"",
    "150 DIM PX(15), PY(15), DX(15), DY(15)",
    "160 FOR S = 0 TO 15",
    "170   PX(S) = RND(1000) + 100",
    "180   PY(S) = RND(800) + 100",
    "190   DX(S) = (RND(4) + 2) * SGN(RND(1) - 0.5)",
    "200   DY(S) = (RND(4) + 2) * SGN(RND(1) - 0.5)",
    "210 NEXT S",
    "220 REM Hoofdlus",
    "230 FOR S = 0 TO 15",
    "240   PX(S) = PX(S) + DX(S)",
    "250   PY(S) = PY(S) + DY(S)",
    "260   IF PX(S) < 0 OR PX(S) > 1247 THEN DX(S) = -DX(S)",
    "270   IF PY(S) < 0 OR PY(S) > 991 THEN DY(S) = -DY(S)",
    "280   PLOT 200, S, 0",
    "290   PLOT 201, PX(S), PY(S)",
    "300 NEXT S",
    "310 GOTO 230",
    "320 REM Smiley Graphic Data"
]

dl, ln = to_data(smiley, 330)
bas_lines.extend(dl)

with open("smiley_swarm.bas", "w") as f:
    f.write("\n".join(bas_lines) + "\n")
