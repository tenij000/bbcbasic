import serial
import time

# 5 Volledig Scherm (1280x1024 BBC BASIC / 720p HDMI) Showcase Demo's + README2.TXT voor Drive 2 (*DRIVE 2)

DEMOS = {
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
        '50 COLOUR 6:PRINT "Achtergrond 1: 16 Hardware Sprites (1280x1024)"',
        '60 PRINT "Achtergrond 2: 6502 Teller op $0900 (@100Hz)"',
        '70 COLOUR 7:PRINT "Voorgrond:     Fullscreen 3D MiniGPU Tunnel!"',
        '80 TIME=0:FOR R%=30 TO 480 STEP 30',
        '90 GCOL 0,(R%*3) AND 255',
        '100 CIRCLE 640,512,R%',
        '110 GLINE 640-R%,512-R%,640+R%,512+R%',
        '120 GLINE 640-R%,512+R%,640+R%,512-R%',
        '130 ?&A002=6:NEXT',
        '140 COLOUR 2:PRINT "Klaar in ";TIME;" cs | IRQ Ticks: ";?&70',
        '150 ?&2F7=0',
    ],
    "VUURWERK": [
        '10 CLS:CLG:*BG ON',
        '20 COLOUR 3:PRINT "=== FULLSCREEN MINIGPU + 16 SPRITES VUURWERK ==="',
        '30 FOR B%=1 TO 6',
        '40 X%=200+RND(880):Y%=180+RND(660):C%=RND(254)+1',
        '50 COLOUR (B% AND 6)+1:PRINT "Vuurbom #";B%;" op (";X%;",";Y%;")!"',
        '60 FOR R%=20 TO 180 STEP 32',
        '70 GCOL 0,C%+R%:CIRCLE X%,Y%,R%',
        '80 GLINE X%-R%,Y%,X%+R%,Y%:GLINE X%,Y%-R%,X%,Y%+R%',
        '90 GLINE X%-R%,Y%-R%,X%+R%,Y%+R%:GLINE X%-R%,Y%+R%,X%+R%,Y%-R%',
        '100 ?&A002=4:NEXT',
        '110 NEXT',
        '120 COLOUR 2:PRINT "Vuurwerk voltooid! 16 Sprites vliegen fullscreen!"',
    ],
    "KLOK": [
        '10 CLS:CLG:*BG OFF',
        '20 COLOUR 3:PRINT "=== FULLSCREEN 100Hz HARDWARE KLOK & RADAR ==="',
        '30 GCOL 0,28:CIRCLE 640,512,380:CIRCLE 640,512,376',
        '40 GCOL 0,255:CIRCLE 640,512,12',
        '50 ?&A020=0:?&A025=1',
        '60 TIME=0:FOR S%=0 TO 15',
        '70 X%=640+((S%-8)*38):Y%=512-((S% AND 7)*38)',
        '80 GCOL 0,3:GLINE 640,512,X%,Y%',
        '90 ?&A021=X% AND 255:?&A022=X% DIV 256',
        '100 ?&A023=Y% AND 255:?&A024=Y% DIV 256',
        '110 ?&A002=12',
        '120 PRINT "Radar sweep ";S%+1;"/16 | TIME = ";TIME;" cs"',
        '130 GCOL 0,192:CIRCLE X%,Y%,16:NEXT',
        '140 *BG ON',
    ],
    "SYNTHBG": [
        '10 CLS:CLG:*BG ON',
        '20 COLOUR 5:PRINT "=== 1984 SYNTHWAVE HORIZON (1280x1024) ==="',
        '30 GCOL 0,224:RECT 0,520,1279,400',
        '40 GCOL 0,252:CIRCLE 640,520,180',
        '50 GCOL 0,31:GLINE 0,520,1279,520',
        '60 FOR Y%=60 TO 520 STEP 46',
        '70 GCOL 0,199:GLINE 0,Y%,1279,Y%:NEXT',
        '80 FOR X%=0 TO 1279 STEP 80',
        '90 GCOL 0,59:GLINE 640,520,X%,20:NEXT',
        '100 COLOUR 3:PRINT "16 Aliens stuiteren nu over het HELE scherm!"',
        '110 FOR K%=0 TO 15:?&A020=K%:?(&2D0+K%)=(K%*19) OR &1A:NEXT',
        '120 COLOUR 2:PRINT "Fullscreen 1280x1024 Multitasking Actief!"',
    ],
}

README2_TXT = (
    "=== WELKOM OP DRIVE 2 (DEMO DISK) ===\r"
    "Start met CHAIN of LOAD + RUN:\r"
    " 1. CHAIN \"MULTITASK\" -> IRQ + GPU\r"
    " 2. CHAIN \"VUURWERK\"  -> Vuurwerk!\r"
    " 3. CHAIN \"SYNTHBG\"   -> 80s Horizon\r"
    " 4. CHAIN \"KLOK\"      -> 100Hz Radar\r"
    " 5. CHAIN \"BENCHMARK\" -> 27MHz Test"
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
    print(send_cmd(s, "*SD", 0.6).strip())
    print(send_cmd(s, "*DRIVE 2", 0.6).strip())
    print(send_cmd(s, "*WIPE", 1.2).strip())

    # Upload alle 5 Fullscreen BBC BASIC + 6502/GPU Demo's naar Drive 2
    for name, lines in DEMOS.items():
        print(f"\nUploaden van {name} (1280x1024 Fullscreen) naar Drive 2...")
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

    # Draai nu live alle 5 de fullscreen demo's achter elkaar en eindig met SYNTHBG + *BG ON!
    for demo, wait_s in [
        ("BENCHMARK", 2.2),
        ("KLOK", 3.5),
        ("VUURWERK", 3.8),
        ("MULTITASK", 2.6),
        ("SYNTHBG", 1.8),
    ]:
        print(f"\n>>> LIVE UITVOEREN OP DRIVE 2: CHAIN \"{demo}\" <<<")
        out = send_cmd(s, f'CHAIN "{demo}"', wait_s)
        print(out.strip())

    s.close()

if __name__ == "__main__":
    main()
