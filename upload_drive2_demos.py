import serial
import time

# 6 Volledig Scherm (1280x1024 BBC BASIC / 720p HDMI) Showcase Demo's + README2.TXT voor Drive 2 (*DRIVE 2)

DEMOS = {
    "CHIPTUNE": [
        '10 CLS:CLG:*BG ON',
        '20 COLOUR 3:PRINT "=== 4-KANAALS 48kHz HDMI CHIPTUNE SYNTHESIZER ==="',
        '30 COLOUR 6:PRINT "Kanaal 0..2: 3-Stemmig Stereo | Kanaal 3: Noise/Drums"',
        '40 COLOUR 7:PRINT "1. Arcade Geluidseffecten (Laser, Power-Up & Explosie):"',
        '50 PRINT "   -> Laser Zap ($A030=220, $A034=&AF)..."',
        '60 PLOT 210,220,&AF:?&A002=35',
        '70 PRINT "   -> Coin / Power-Up ($A031=80, $A035=&9F)..."',
        '80 PLOT 211,80,&9F:?&A002=35',
        '90 PRINT "   -> Boss Explosie ($A033=20, $A037=&8F)..."',
        '100 PLOT 213,20,&8F:?&A002=45',
        '110 COLOUR 2:PRINT "2. 4-Kanaals 1980s Arcade Chiptune + GPU Equalizer:"',
        '120 RESTORE:FOR N%=1 TO 16:READ M%,H%,B%,D%',
        '130 ?&A030=M%:?&A034=&8F:?&A031=H%:?&A035=&8C',
        '140 ?&A032=B%:?&A036=&CB:IF D% THEN ?&A033=D%:?&A037=&CF',
        '150 X%=80+(N%*70):GCOL 0,(N%*19) OR 3',
        '160 RECT X%,120,48,M%*3,1:GCOL 0,255:CIRCLE X%+24,140+M%*3,22,1',
        '170 FOR W%=1 TO 900:NEXT:NEXT',
        '180 ?&A030=120:?&A031=150:?&A032=180:?&A034=&8F:?&A035=&8F:?&A036=&8F',
        '190 COLOUR 3:PRINT "C-Majeur Finale Akkoord (120:150:180) + Live Alien SFX!"',
        '200 DATA 120,90,60,18, 150,120,60,0, 180,150,60,45, 240,180,60,0',
        '210 DATA 160,120,80,18, 200,160,80,0, 240,200,80,45, 200,160,80,0',
        '220 DATA 180,135,90,18, 225,180,90,0, 180,135,90,45, 150,112,90,0',
        '230 DATA 120,90,60,18, 150,120,60,45, 180,150,60,18, 240,180,120,24',
    ],
    "SOLID3D": [
        '10 MODE 1:*BG ON',
        '20 VDU 23,224,&3C,&7E,&F8,&F0,&F8,&7E,&3C,0',
        '30 VDU 23,225,&3C,&7E,&DB,&FF,&FF,&FF,&AA,0',
        '40 VDU 23,226,&18,&3C,&7E,&DB,&FF,&24,&5A,&A5',
        '50 VDU 23,227,&18,&3C,&7E,&FF,&FF,&7E,&3C,&18',
        '60 GCOL 0,4:RECT 0,0,1279,240,1:GCOL 0,31:GLINE 0,240,1279,240',
        '70 GCOL 0,224:CIRCLE 640,620,220,1:GCOL 0,252:CIRCLE 640,620,165,1',
        '80 GCOL 0,63:CIRCLE 1040,780,75,1:GCOL 0,255:CIRCLE 1040,780,115',
        '90 GCOL 0,28:MOVE 80,240:MOVE 360,240:PLOT 85,240,640',
        '100 GCOL 0,12:MOVE 360,240:MOVE 480,200:PLOT 85,240,640',
        '110 GCOL 0,252:MOVE 420,200:MOVE 680,200:PLOT 85,580,700',
        '120 GCOL 0,196:MOVE 680,200:MOVE 830,160:PLOT 85,580,700',
        '130 GCOL 0,63:MOVE 780,240:MOVE 1080,240:PLOT 85,960,620',
        '140 GCOL 0,19:MOVE 1080,240:MOVE 1220,190:PLOT 85,960,620',
        '150 COLOUR 132:COLOUR 3:COLOUR 141:PRINT " === SOLID 3D GPU & VDU 23 UDG === "',
        '160 COLOUR 132:COLOUR 3:COLOUR 141:PRINT " === SOLID 3D GPU & VDU 23 UDG === "',
        '170 COLOUR 128:COLOUR 7:PRINT "PLOT 85=Driehoek | PLOT 101=Rechthoek | PLOT 153=Cirkel"',
        '180 COLOUR 3:PRINT "VDU 23 Arcade UDG: ";:FOR I%=1 TO 5',
        '190 COLOUR 3:PRINT CHR$(224);" ";:COLOUR 1:PRINT CHR$(225);" ";',
        '200 COLOUR 2:PRINT CHR$(226);" ";:COLOUR 6:PRINT CHR$(227);" ";:NEXT:PRINT',
        '210 PLOT 210,120,&9F:PLOT 211,150,&9F:PLOT 212,180,&9F',
    ],
    "ALIENWAR": [
        '10 CLS:CLG:*BG ON:?&A028=0:?&A027=0',
        '20 FOR K%=0 TO 15:?(&2D0+K%)=((K% AND 1)*192)+54:NEXT',
        '30 COLOUR 3:PRINT "=== ALIEN WAR: COLLISION, BOSS & HDMI SFX ==="',
        '40 COLOUR 6:PRINT "Sprite 15 = 64x64 Rode Mega-Boss ($A029=$21)"',
        '50 PRINT "Sprite 0..2 = 16x16 Snelle Scouts | Live HDMI Geluid!"',
        '60 GCOL 0,28:CIRCLE 640,512,90:CIRCLE 640,512,350',
        '70 FOR T%=1 TO 10:PLOT 210,180+(T%*6),&EF:FOR D%=1 TO 2500:NEXT',
        '80 C%=?&A027:B%=?&A028',
        '90 ?&A020=15:BX%=?&A021+(?&A022*256):BY%=?&A023+(?&A024*256)',
        '100 GCOL 0,(T%*29) OR 3:GLINE 640,512,BX%,BY%:CIRCLE BX%,BY%,36',
        '110 COLOUR (T% AND 6)+1',
        '120 PRINT "Sweep ";T%;"/10 | Botsingen ($A028)=";B%;" | Boss=(";BX%;",";BY%;")"',
        '130 IF C% THEN COLOUR 1:PRINT "  >>> HIT OP SPELER DOOR ALIEN #";C% AND 15;"! <<<":?&A027=0',
        '140 NEXT:COLOUR 2:PRINT "Totaal Alien-Botsingen: ";?&A028',
    ],
    "BENCHMARK": [
        '10 CLS:CLG:COLOUR 3:PRINT "=== 27 MHz 6502 vs 1981 BBC MICRO ==="',
        '20 COLOUR 7:PRINT "1. BASIC Loop (10.000x FOR/NEXT)..."',
        '30 TIME=0:FOR I%=1 TO 10000:NEXT:T1%=TIME',
        '40 PRINT "   Tijd: ";T1%;" cs (BBC Micro: ~950 cs)"',
        '50 PRINT "2. 6502 Machinetaal (65.536x loop)..."',
        '60 P%=&900:[OPT 2 : LDY #0 : LDX #0 : INX : BNE &904 : INY : BNE &902 : RTS :]',
        '70 TIME=0:CALL &900:T2%=TIME',
        '80 PRINT "   Tijd: ";T2%;" cs (327.680 kloktikken!)"',
        '90 PRINT "3. Hardware MiniGPU (60 Fullscreen Cirkels+Lijnen)..."',
        '100 TIME=0:FOR I%=20 TO 460 STEP 20',
        '110 GCOL 0,(I% DIV 20)*11:CIRCLE 640,512,I%',
        '120 GLINE 40,512-I%,1240,512+I%:NEXT:T3%=TIME',
        '130 PRINT "   GPU Tijd: ";T3%;" cs!"',
        '140 COLOUR 2:PRINT "Snelheidsfactor: ~";950 DIV T1%;"x sneller dan 1981 BBC Micro!"',
    ],
    "MULTITASK": [
        '10 CLS:CLG:*BG ON',
        '20 COLOUR 3:PRINT "=== 100Hz IRQ MULTITASKING SHOWCASE ==="',
        '30 ?&70=0:P%=&900:[OPT 2:INC &70:RTS:]',
        '40 ?&2F6=0:?&2F7=&09',
        '50 COLOUR 6:PRINT "Achtergrond 1: 16 Multi-Color Sprites + Boss"',
        '60 PRINT "Achtergrond 2: 6502 Teller op $0900 (@100Hz)"',
        '70 COLOUR 7:PRINT "Voorgrond:     Fullscreen 3D MiniGPU Tunnel!"',
        '80 TIME=0:FOR R%=30 TO 480 STEP 30',
        '90 GCOL 0,(R%*3) AND 255',
        '100 CIRCLE 640,512,R%',
        '110 GLINE 640-R%,512-R%,640+R%,512+R%',
        '120 GLINE 640-R%,512+R%,640+R%,512-R%',
        '130 FOR D%=1 TO 150:NEXT:NEXT',
        '140 COLOUR 2:PRINT "Klaar in ";TIME;" cs | IRQ Ticks: ";?&70;" | Botsingen: ";?&A028',
        '150 ?&2F7=0',
    ],
    "VUURWERK": [
        '10 CLS:CLG:*BG ON',
        '20 COLOUR 3:PRINT "=== FULLSCREEN MINIGPU + HDMI GELUID VUURWERK ==="',
        '30 FOR B%=1 TO 6',
        '40 X%=200+RND(880):Y%=180+RND(660):C%=RND(254)+1',
        '50 COLOUR (B% AND 6)+1:PRINT "Vuurbom #";B%;" op (";X%;",";Y%;")!"',
        '55 PLOT 210,90+(B%*15),&9F:PLOT 213,18+(B%*4),&8F',
        '60 FOR R%=20 TO 180 STEP 32',
        '70 GCOL 0,C%+R%:CIRCLE X%,Y%,R%',
        '80 GLINE X%-R%,Y%,X%+R%,Y%:GLINE X%,Y%-R%,X%,Y%+R%',
        '90 GLINE X%-R%,Y%-R%,X%+R%,Y%+R%:GLINE X%-R%,Y%+R%,X%+R%,Y%-R%',
        '100 FOR D%=1 TO 90:NEXT:NEXT',
        '110 NEXT',
        '120 COLOUR 2:PRINT "Vuurwerk klaar! Alien-botsingen: ";?&A028',
    ],
    "KLOK": [
        '10 CLS:CLG:*BG OFF',
        '20 COLOUR 3:PRINT "=== FULLSCREEN 100Hz HARDWARE KLOK & RADAR ==="',
        '30 GCOL 0,28:CIRCLE 640,512,380:CIRCLE 640,512,376',
        '40 GCOL 0,255:CIRCLE 640,512,12',
        '50 ?&A020=0:?&A025=1:?&A029=&23',
        '60 TIME=0:FOR S%=0 TO 15',
        '70 X%=640+((S%-8)*38):Y%=512-((S% AND 7)*38)',
        '80 GCOL 0,3:GLINE 640,512,X%,Y%',
        '90 ?&A021=X% AND 255:?&A022=X% DIV 256',
        '100 ?&A023=Y% AND 255:?&A024=Y% DIV 256',
        '110 PLOT 210,120+(S%*4),&CC:?&A002=12',
        '120 PRINT "Radar sweep ";S%+1;"/16 | TIME = ";TIME;" cs"',
        '130 GCOL 0,192:CIRCLE X%,Y%,16:NEXT',
        '140 *BG ON',
    ],
    "SYNTHBG": [
        '10 CLS:CLG:*BG ON',
        '20 COLOUR 5:PRINT "=== 1984 SYNTHWAVE HORIZON + BOSS ALIEN ==="',
        '30 GCOL 0,224:RECT 0,520,1279,400',
        '40 GCOL 0,252:CIRCLE 640,520,180,1',
        '50 GCOL 0,31:GLINE 0,520,1279,520',
        '60 FOR Y%=60 TO 520 STEP 46',
        '70 GCOL 0,199:GLINE 0,Y%,1279,Y%:NEXT',
        '80 FOR X%=0 TO 1279 STEP 80',
        '90 GCOL 0,59:GLINE 640,520,X%,20:NEXT',
        '100 COLOUR 3:PRINT "16 Multi-Color Aliens + 64x64 Boss + HDMI Audio SFX!"',
        '110 FOR K%=0 TO 15:?&A020=K%:?(&2D0+K%)=(K%*19) OR &1A:NEXT',
        '115 ?&A030=120:?&A031=150:?&A034=&8E:?&A035=&8E',
        '120 COLOUR 2:PRINT "Hardware Collision Teller ($A028): ";?&A028',
    ],
    "TELETEKST": [
        '10 MODE 7:*BG ON',
        '20 GCOL 0,20:CIRCLE 640,420,260:GCOL 0,196:RECT 60,80,1160,860',
        '30 COLOUR 128:COLOUR 7:PRINT "P101  NOS TELETEKST   6502 MINIGPU 720P"',
        '40 COLOUR 132:COLOUR 3:COLOUR 141:PRINT "  === NOS TELETEKST 101 ===   "',
        '50 COLOUR 132:COLOUR 3:COLOUR 141:PRINT "  === NOS TELETEKST 101 ===   "',
        '60 COLOUR 128:S$="":FOR I%=1 TO 5:S$=S$+CHR$(191)+CHR$(255):NEXT',
        '70 FOR C%=1 TO 6:COLOUR C%:PRINT S$;:NEXT:PRINT',
        '80 COLOUR 129:COLOUR 7:PRINT " NIEUWS ";:COLOUR 128:COLOUR 3:PRINT " 27MHz 6502 + 8MB SDRAM GPU! "',
        '90 COLOUR 130:COLOUR 0:PRINT " GELUID ";:COLOUR 128:COLOUR 6:PRINT " 4-Ch 48kHz Stereo HDMI PSG! "',
        '100 COLOUR 133:COLOUR 7:PRINT " SOLID  ";:COLOUR 128:COLOUR 2:PRINT " PLOT 85/101/153 & VDU 23!   "',
        '110 COLOUR 131:COLOUR 0:PRINT " SPRITE ";:COLOUR 128:COLOUR 7:PRINT " 16 Aliens + 64x64 Boss IRQ! "',
        '120 COLOUR 6:PRINT STRING$(36,CHR$(140))',
        '130 COLOUR 3:PRINT "102 ";:COLOUR 7:PRINT "Binnenland: HIMEM=&7A00 in elke MODE"',
        '140 COLOUR 3:PRINT "201 ";:COLOUR 2:PRINT " Arcade:     CHAIN ";CHR$(34);"SOLID3D";CHR$(34);" (3D+UDG)"',
        '150 COLOUR 3:PRINT "701 ";:COLOUR 6:PRINT "Weerbericht: ";:COLOUR 3:PRINT CHR$(191);CHR$(191);" Zonnig 24 C"',
        '160 COLOUR 132:COLOUR 3:PRINT " 101 Nieuws  201 Sport  701 Weer  888 "',
        '170 COLOUR 128:COLOUR 7:PLOT 210,160,&8F:PLOT 211,200,&8F',
    ],
    "MODES": [
        '10 MODE 2:*BG ON',
        '20 COLOUR 129:COLOUR 3:PRINT " MODE 2: 20x20 "',
        '30 COLOUR 128:COLOUR 6:PRINT "MEGA ARCADE FONT"',
        '40 GCOL 0,252:CIRCLE 640,512,320:PLOT 210,120,&9F:?&A002=90',
        '50 MODE 129:COLOUR 132:COLOUR 3:COLOUR 141:PRINT " MODE 1: 40x20 ARCADE "',
        '60 COLOUR 132:COLOUR 3:COLOUR 141:PRINT " MODE 1: 40x20 ARCADE "',
        '70 COLOUR 128:COLOUR 2:PRINT "MODE 129 behoudt 3D Graphics eronder!"',
        '80 PLOT 211,160,&9F:?&A002=90',
        '90 MODE 131:PRINT "=== MODE 3: 80x41 GROENE FOSFOR TERMINAL + 3D GRAPHICS ==="',
        '100 COLOUR 3:PRINT "Alle 8 BBC Modes (MODE 0..7) klaar! Actieve MODE = ";?&A02A',
    ],
}

README2_TXT = (
    "=== WELKOM OP DRIVE 2 (DEMO DISK) ===\r"
    "Start met CHAIN \"NAAM\":\r"
    "1. SOLID3D   -> 3D Fill + VDU 23 UDG!\r"
    "2. TELETEKST -> MODE 7 NOS Teletekst!\r"
    "3. CHIPTUNE  -> 4-Ch HDMI Audio!\r"
    "4. MODES / ALIENWAR / SYNTHBG"
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

    print("=== Overschakelen naar MicroSD Drive 2 (*SD & *DRIVE 2) ===")
    print(send_cmd(s, "*BG OFF", 0.4).strip())
    print(send_cmd(s, "MODE 0", 0.5).strip())
    print(send_cmd(s, "*SD", 0.5).strip())
    print(send_cmd(s, "*DRIVE 2", 0.6).strip())
    print(send_cmd(s, "*WIPE", 1.2).strip())

    # Upload alle Fullscreen BBC BASIC + HDMI Sound + MODE 0..7 + Solid3D Demo's naar Drive 2
    for name, lines in DEMOS.items():
        print(f"\nUploaden van {name} naar Drive 2...")
        send_cmd(s, "NEW", 0.2)
        for line in lines:
            send_cmd(s, line, 0.08)
        out = send_cmd(s, f'SAVE "{name}"', 1.4)
        print(out.strip())

    # Upload README2.TXT naar Drive 2
    raw = README2_TXT.encode("ascii")
    print(f"\nUploaden van README2.TXT ({len(raw)} bytes) naar Drive 2...")
    send_cmd(s, 'F%=OPENOUT("README2.TXT")', 0.3)
    for i in range(0, len(raw), 8):
        chunk = raw[i:i+8]
        cmd = ":".join(f"BPUT#F%,{b}" for b in chunk)
        send_cmd(s, cmd, 0.05)
    print(send_cmd(s, "CLOSE#F%", 1.2).strip())

    print("\n=== Catalogus van Drive 2 (*INFO) ===")
    print(send_cmd(s, "*INFO", 0.8).strip())

    # Draai nu live CHIPTUNE, TELETEKST en eindig op het prachtige SOLID3D scherm!
    for demo, wait_s in [
        ("CHIPTUNE", 4.5),
        ("TELETEKST", 2.0),
        ("SOLID3D", 2.5),
    ]:
        print(f"\n>>> LIVE UITVOEREN OP DRIVE 2: CHAIN \"{demo}\" <<<")
        out = send_cmd(s, f'CHAIN "{demo}"', wait_s)
        print(out.strip())

    s.close()

if __name__ == "__main__":
    main()
