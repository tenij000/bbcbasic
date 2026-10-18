import serial
import time

# =====================================================================
# DRIVE 3: SPEELBARE ARCADE GAMES DISK VOOR TANG NANO 20K (SD-MOS 1.70)
# Gebruikt:
#   - ADVAL(0) / ?&A004 Live PS/2 & UART Joypad (WASD / Pijltjes / Spatie)
#   - POINT(X,Y) Hardware SDRAM Pixel-Readback (muren, blokjes & trails!)
#   - GCOL 3 Hardware XOR (flikkervrije ballen, lasers & vizieren)
#   - PLOT 85 / RECT ...,1 / CIRCLE ...,1 Hardware Solid Fill
#   - *SSAVE / *SLOAD 6ms 32-Bit Hardware Screen Blitter
#   - 16 Hardware Sprites + 4-Kanaals 48kHz HDMI Geluidschip
# =====================================================================

GAMES = {
    "MENU": [
        '10 MODE 1:*BG ON',
        '15 *GCLS',
        '20 VDU 23,224,60,126,248,240,248,126,60,0',
        '25 VDU 23,225,56,124,254,214,254,254,170,0',
        '30 GCOL 0,4:RECT 20,40,1240,940:GCOL 0,6:RECT 32,52,1216,916',
        '40 GCOL 0,1:MOVE 60,80:MOVE 640,360:PLOT 85,1220,80',
        '50 COLOUR 132:COLOUR 3:COLOUR 141:PRINT "   === DRIVE 3: ARCADE GAME HAL ===   "',
        '60 COLOUR 132:COLOUR 3:COLOUR 141:PRINT "   === DRIVE 3: ARCADE GAME HAL ===   "',
        '70 COLOUR 128:PRINT',
        '80 COLOUR 6:PRINT " ";CHR$(224);" [1] CHAIN ";CHR$(34);"ARKANOID";CHR$(34);" (Breakout + POINT)"',
        '90 COLOUR 3:PRINT " ";CHR$(225);" [2] CHAIN ";CHR$(34);"PACMAN";CHR$(34);"   (Maze + VDU 23)"',
        '100 COLOUR 2:PRINT " ";CHR$(224);" [3] CHAIN ";CHR$(34);"INVADERS";CHR$(34);" (XOR Laser + Boss)"',
        '110 COLOUR 5:PRINT " ";CHR$(225);" [4] CHAIN ";CHR$(34);"TRON";CHR$(34);"     (Lightcycles)"',
        '120 PRINT:COLOUR 7:PRINT " Besturing: Pijltjes / WASD + Spatie"',
        '130 COLOUR 3:PRINT " Of typ: CHAIN ";CHR$(34);"ARKANOID";CHR$(34)',
        '140 PLOT 210,120,&8F:PLOT 211,150,&8F:PLOT 212,180,&8F',
    ],
    "ARKANOID": [
        '10 MODE 1:*BG OFF',
        '15 *GCLS',
        '20 COLOUR 132:COLOUR 3:COLOUR 141:PRINT "   === ARKANOID 720P (DRIVE 3) ===    "',
        '30 COLOUR 132:COLOUR 3:COLOUR 141:PRINT "   === ARKANOID 720P (DRIVE 3) ===    "',
        '40 COLOUR 128:GCOL 0,7:RECT 40,40,1200,820,1:GCOL 0,0:RECT 56,40,1168,804,1',
        '50 FOR R%=0 TO 3:GCOL 0,R%+1:FOR C%=0 TO 7',
        '60 RECT 88+C%*140,620+R%*48,124,34,1:NEXT:NEXT',
        '70 BX%=640:BY%=220:DX%=28:DY%=28:PX%=540:SC%=0',
        '80 FOR T%=1 TO 45:J%=ADVAL(0)',
        '90 IF J% AND 4 PX%=PX%-48 ELSE IF J% AND 8 PX%=PX%+48 ELSE PX%=BX%-90',
        '100 IF PX%<64 PX%=64 ELSE IF PX%>1020 PX%=1020',
        '110 GCOL 3,6:RECT PX%,80,180,24,1:GCOL 3,7:CIRCLE BX%,BY%,16,1',
        '120 ?&A002=4:GCOL 3,6:RECT PX%,80,180,24,1:GCOL 3,7:CIRCLE BX%,BY%,16,1',
        '130 NX%=BX%+DX%:NY%=BY%+DY%:IF NX%<80 OR NX%>1196 DX%=-DX%:PLOT 210,180,&8C',
        '140 IF NY%>810 DY%=-DY%:PLOT 210,200,&8C',
        '150 IF NY%<120 DY%=28:PLOT 211,120,&9F',
        '160 H%=POINT(BX%,NY%+18):IF H%>=1 AND H%<=4 THEN GOSUB 210',
        '170 BX%=BX%+DX%:BY%=BY%+DY%:NEXT',
        '180 GCOL 0,6:RECT PX%,80,180,24,1:GCOL 0,7:CIRCLE BX%,BY%,16,1',
        '190 COLOUR 2:PRINT "SCORE: ";SC%;" | LAATSTE PIXEL=";H%;" | JOY=";ADVAL(0)',
        '200 END',
        '210 SC%=SC%+H%*100:DY%=-DY%:BC%=(BX%-88) DIV 140:BR%=(NY%+18-620) DIV 48',
        '220 GCOL 0,0:RECT 88+BC%*140,620+BR%*48,124,34,1',
        '230 PLOT 210,140+H%*25,&9F:PLOT 213,8,&8C:RETURN',
    ],
    "PACMAN": [
        '10 MODE 1:*BG OFF',
        '15 *GCLS',
        '20 VDU 23,224,60,126,248,240,248,126,60,0',
        '25 VDU 23,225,56,124,254,214,254,254,170,0',
        '30 COLOUR 129:COLOUR 3:COLOUR 141:PRINT "   === PAC-MAN NEON MAZE (DRIVE 3) === "',
        '40 COLOUR 129:COLOUR 3:COLOUR 141:PRINT "   === PAC-MAN NEON MAZE (DRIVE 3) === "',
        '50 COLOUR 128:GCOL 0,4:RECT 40,60,1200,780:RECT 52,72,1176,756',
        '60 RECT 220,240,260,140,1:RECT 800,240,260,140,1',
        '70 RECT 220,520,260,140,1:RECT 800,520,260,140,1:RECT 540,360,200,180,1',
        '80 GCOL 0,3:FOR X%=130 TO 1150 STEP 84:CIRCLE X%,150,12,1:CIRCLE X%,450,12,1:CIRCLE X%,740,12,1:NEXT',
        '90 ?&A020=0:?&A029=&03:?&A025=1:?&A020=1:?&A029=&01:?&A025=1:?&A002=16',
        '100 PX%=130:PY%=150:GX%=1150:GY%=740:SC%=0:VX%=42:VY%=0',
        '110 FOR T%=1 TO 32:J%=ADVAL(0)',
        '120 IF J% AND 1 VX%=0:VY%=30 ELSE IF J% AND 2 VX%=0:VY%=-30',
        '130 IF J% AND 4 VX%=-42:VY%=0 ELSE IF J% AND 8 VX%=42:VY%=0',
        '140 IF POINT(PX%+VX%,PY%+VY%)=4 THEN VX%=0:VY%=30',
        '150 PX%=PX%+VX%:PY%=PY%+VY%:IF PX%>1140 VX%=0:VY%=30',
        '160 IF PY%>730 VX%=-42:VY%=0',
        '170 IF POINT(PX%,PY%)=3 SC%=SC%+50:GCOL 0,0:CIRCLE PX%,PY%,16,1:PLOT 210,140+(T% AND 1)*40,&8E',
        '180 PLOT 200,0,0:PLOT 201,PX%,820-PY%*3 DIV 4',
        '190 GX%=GX%-28:PLOT 200,1,0:PLOT 201,GX%,820-GY%*3 DIV 4:?&A002=4:NEXT',
        '200 COLOUR 3:PRINT CHR$(224);" PAC-SCORE: ";SC%;" ";CHR$(225);" DOTS GEGETEN MET POINT(X,Y)!"',
    ],
    "INVADERS": [
        '10 MODE 1:*BG ON',
        '15 *GCLS',
        '20 VDU 23,224,24,60,126,255,255,126,60,24',
        '30 COLOUR 133:COLOUR 3:COLOUR 141:PRINT "  === GALAXIAN BOSS INVADERS (D3) === "',
        '40 COLOUR 133:COLOUR 3:COLOUR 141:PRINT "  === GALAXIAN BOSS INVADERS (D3) === "',
        '50 COLOUR 128:GCOL 0,2:FOR B%=0 TO 3:MOVE 140+B%*290,180:MOVE 220+B%*290,270:PLOT 85,300+B%*290,180:NEXT',
        '60 GCOL 0,4:MOVE 0,40:MOVE 0,120:PLOT 85,640,90:PLOT 85,1279,130',
        '70 SX%=640:SC%=0:FOR T%=1 TO 18:J%=ADVAL(0)',
        '80 IF J% AND 4 SX%=SX%-48 ELSE IF J% AND 8 SX%=SX%+48 ELSE SX%=340+(T%*42)',
        '90 GCOL 3,6:RECT SX%-36,70,72,28,1',
        '100 IF (J% AND 16) OR (T% AND 1) THEN GOSUB 150 ELSE ?&A002=5',
        '110 GCOL 3,6:RECT SX%-36,70,72,28,1:NEXT',
        '120 GCOL 0,6:RECT SX%-36,70,72,28,1',
        '130 COLOUR 2:PRINT CHR$(224);" SCORE=";SC%;" | BOSS BOTSINGEN ($A028)=";?&A028',
        '140 END',
        '150 GCOL 3,3:GLINE SX%,105,SX%,820:CIRCLE SX%,820,28',
        '160 PLOT 210,220,&AF:PLOT 213,10,&8C:?&A002=5',
        '170 GCOL 3,3:GLINE SX%,105,SX%,820:CIRCLE SX%,820,28:SC%=SC%+250:RETURN',
    ],
    "TRON": [
        '10 MODE 1:*BG OFF',
        '15 *GCLS',
        '20 COLOUR 134:COLOUR 0:COLOUR 141:PRINT "   === TRON 3D LIGHTCYCLES (DRIVE 3) ==="',
        '30 COLOUR 134:COLOUR 0:COLOUR 141:PRINT "   === TRON 3D LIGHTCYCLES (DRIVE 3) ==="',
        '40 COLOUR 128:GCOL 0,7:RECT 40,40,1200,800:RECT 48,48,1184,784',
        '50 X1%=240:Y1%=440:VX%=16:VY%=0:X2%=1040:Y2%=440:WX%=-16:WY%=0',
        '60 FOR T%=1 TO 42:J%=ADVAL(0)',
        '70 IF J% AND 1 VX%=0:VY%=16 ELSE IF J% AND 2 VX%=0:VY%=-16',
        '80 IF J% AND 4 VX%=-16:VY%=0 ELSE IF J% AND 8 VX%=16:VY%=0',
        '90 IF POINT(X1%+VX%*2,Y1%+VY%*2)<>0 THEN VX%=0:VY%=16:PLOT 211,180,&9F',
        '100 IF POINT(X2%+WX%*2,Y2%+WY%*2)<>0 THEN WX%=0:WY%=-16:PLOT 212,150,&9F',
        '110 X1%=X1%+VX%:Y1%=Y1%+VY%:X2%=X2%+WX%:Y2%=Y2%+WY%',
        '120 GCOL 0,6:RECT X1%-6,Y1%-6,12,12,1:GCOL 0,1:RECT X2%-6,Y2%-6,12,12,1',
        '130 PLOT 210,80+T%*2,&4A:?&A002=3:NEXT',
        '140 GCOL 3,3:CIRCLE X2%,Y2%,55,1:PLOT 213,18,&8F',
        '150 COLOUR 6:PRINT "CYAAN SPELER WINT! POINT-COLLISION OP (";X2%;",";Y2%;")"',
    ],
}

GAMES_TXT = (
    "=== DRIVE 3: ARCADE GAME DISK ===\r"
    "Start met CHAIN \"NAAM\":\r"
    "1. MENU     -> Arcade Keuzemenu\r"
    "2. ARKANOID -> Breakout + POINT!\r"
    "3. PACMAN   -> Neon Maze + VDU 23!\r"
    "4. INVADERS -> Galaxian XOR Laser!\r"
    "5. TRON     -> Lightcycles Arena!"
)

def send_cmd(s, cmd, wait=0.4):
    s.write((cmd + "\r").encode("ascii"))
    time.sleep(wait)
    raw = s.read_all()
    return "".join(chr(b) for b in raw if b in (10, 13) or 32 <= b < 127)

def main():
    s = serial.Serial("COM6", 115200, timeout=0.5)
    s.write(b"\x1b\r")
    time.sleep(0.3)
    s.read_all()

    print("=== Overschakelen naar MicroSD Drive 3 (*SD & *DRIVE 3) ===")
    print(send_cmd(s, "*BG OFF", 0.4).strip())
    print(send_cmd(s, "MODE 0", 0.5).strip())
    print(send_cmd(s, "*SD", 0.5).strip())
    print(send_cmd(s, "*DRIVE 3", 0.6).strip())
    print(send_cmd(s, "*WIPE", 1.2).strip())

    for name, lines in GAMES.items():
        print(f"\nUploaden van spel {name} naar Drive 3...")
        send_cmd(s, "NEW", 0.2)
        for line in lines:
            send_cmd(s, line, 0.08)
        out = send_cmd(s, f'SAVE "{name}"', 1.4)
        print(out.strip())

    raw = GAMES_TXT.encode("ascii")
    print(f"\nUploaden van GAMES.TXT ({len(raw)} bytes) naar Drive 3...")
    send_cmd(s, 'F%=OPENOUT("GAMES.TXT")', 0.3)
    for i in range(0, len(raw), 8):
        chunk = raw[i:i+8]
        cmd = ":".join(f"BPUT#F%,{b}" for b in chunk)
        send_cmd(s, cmd, 0.05)
    print(send_cmd(s, "CLOSE#F%", 1.2).strip())

    print("\n=== Catalogus van Drive 3 (*INFO) ===")
    print(send_cmd(s, "*INFO", 0.8).strip())

    # Draai alle 4 de spellen kort achter elkaar live om ze te testen en eindig op ARKANOID!
    for game, wait_s in [
        ("TRON", 4.0),
        ("PACMAN", 4.0),
        ("INVADERS", 3.5),
        ("ARKANOID", 5.0),
    ]:
        print(f"\n>>> LIVE SPELEN OP DRIVE 3: CHAIN \"{game}\" <<<")
        out = send_cmd(s, f'CHAIN "{game}"', wait_s)
        print(out.strip())

    s.close()

if __name__ == "__main__":
    main()
