# 🖥️ Tang Nano 20K — 27 MHz 6502 Retro Workstation & HDMI MiniGPU

Een complete, zelfstandige **8-bit jaren '80 homecomputer op één FPGA** (Sipeed Tang Nano 20K / Gowin GW2AR-18C), aangedreven door een **27,000 MHz 6502 CPU**, **Acorn BBC BASIC II**, een **eigen 4 KB SD-MOS besturingssysteem**, een **Olimex PS/2-toetsenbordinterface** en een **74,25 MHz 720p HDMI 2D MiniGPU** met SDRAM-framebuffer, 16 hardware sprites en een 80×41 kleurenterminal met jaren '70/'80 CRT hardware-scrolling.

---

## ✨ Belangrijkste Kenmerken (Features)

* **⚡ Turbo 6502 Processor (27,000 MHz):**
  * Draait op de systeemklok van 27 MHz (13,5× sneller dan een originele BBC Micro en 27× sneller dan een Commodore 64).
  * Volledige hardware `RDY`-synchronisatie met de GPU, MicroSD-controller, tekst-terminal en hardware delay-timer (`$A002`).
  * Inclusief de legendarische **ingebouwde 6502 Inline Assembler** (`[ ... ]`) van BBC BASIC II.
* **🎨 74,25 MHz 720p HDMI MiniGPU & 3D/2D Hardware Solid Fill Engine:**
  * Volledig 64 Mbit SDRAM framebuffer met hardware-versnelde 2D- én 3D-solid-fill commando's op 74,25 MHz rechtstreeks vanuit BBC BASIC:
    * `GLINE X1, Y1, X2, Y2` / `PLOT 5, X, Y` (Bresenham hardware lijn-engine)
    * `RECT X, Y, BREEDTE, HOOGTE [, 1]` & `PLOT 101, X2, Y2` (Hardware rechthoek-omtrek of **74,25 MHz Solid Filled Rectangle**!)
    * `CIRCLE X, Y, STRAAL [, 1]` & `PLOT 153, R, 0` (Midpoint hardware cirkel-omtrek of **Solid Filled Disc / Planeet**!)
    * `MOVE X1, Y1 : MOVE X2, Y2 : PLOT 85, X3, Y3` (**Hardware Solid Filled Triangle Engine** voor razendsnelle gevulde 3D-polygonen en piramides!)
    * `GCOL 0..4, KLEUR`: **Volledige BBC BASIC Logische Read-Modify-Write Modi** in hardware (`0`=Overschrijven, `1`=OR, `2`=AND, `3`=**XOR** voor flikkervrije crosshairs/lasers/rubber-banding, `4`=INVERT) + **Volledig 256-Kleuren RGB332 Palet (`GCOL m, 8..255`)**!
    * `POINT(X, Y)` & `?$A02B`: **Hardware Pixel-Readback Engine** (`PLOT 222, X, Y`) leest elke pixel uit het 8 MB SDRAM terug naar BBC BASIC voor pixel-exacte botsingsdetectie, doolhof-muren en kleurenpipet!
    * `*SSAVE [0..14]` & `*SLOAD [0..14]`: **6 ms 32-Bit Hardware Screen Blitter** (`PLOT 220` / `PLOT 221`) kopieert of herstelt een compleet `1280×1024` scherm in **163.840 32-bit SDRAM-bursts (~6 milliseconden!)** naar/van 15 vrije SDRAM-slots!
* **🕹️ Live Arcade Joypad / Key-Matrix Register (`$A004`), `ADVAL(0)` & Non-Blocking `INKEY(0)`:**
  * Houdt in hardware (`ps2_keyboard.v`) live het indrukken (`Make`) en loslaten (`Break F0`) bij van 8 gelijktijdige actie-richtingen: `Up/W` (`bit 0`), `Down/S` (`bit 1`), `Left/A` (`bit 2`), `Right/D` (`bit 3`), `Fire1 Space/Z` (`bit 4`), `Fire2 X/Shift/Ctrl` (`bit 5`), `Select C/Tab` (`bit 6`) en `Start Enter/Esc` (`bit 7`)!
  * Direct uit te lezen via `?$A004`, `ADVAL(0)` (`OSBYTE &80`) en non-blocking `INKEY(0)` / `INKEY$(0)` (`OSBYTE &81`).
* **🔤 `VDU 23` User-Defined Characters (UDG / Custom Arcade Font Designer):**
  * Herdefinieer live vanuit BBC BASIC elk 8×8 karakter (`CHR$(224..255)` of `CHR$(32..127)`) met `VDU 23, char, b0, b1, b2, b3, b4, b5, b6, b7` voor eigen Pac-Man, Spookjes, Space Invaders, tegels en valutasymbolen in elke `MODE 0..7`!
* **👾 16 Multi-Color Hardware Sprites (`16×16` Scouts, `32×32` Fighters & `64×64` Mega-Boss!):**
  * Onafhankelijke transparante sprite-overlay bovenop de tekst- en framebuffer-laag over het **volledige `1280×1024` (720p HDMI) scherm**.
  * **15-Kleuren Neon Arcade Palet & Schaling per Sprite (`$A029` `SPR_ATTR`):** Kies per sprite een eigen neon-kleur (`bits 3..0`) én formaat (`bits 5..4`: `00`=`32×32` standaard, `01`=`16×16` snelle Scout, `10/11`=`64×64` Mega-Boss!).
  * **Hardware Sprite-tot-Sprite Botsingsdetectie & Biljart-Physics (`$A027` & `$A028`):** Wanneer twee sprites elkaar raken op het scherm, draaien ze in hardware automatisch om (biljart-botsing!), telt `$A028` (`SPR_BOUNCES`) elke botsing en meldt `$A027` (`SPR_COLL`) direct welke vijand Sprite 0 (de speler) heeft geraakt!
  * Live te bewerken en te testen met de meegeleverde **Retro FPGA Sprite Studio PRO** (`sprite_editor.py`).
* **🎵 4-Kanaals 48 kHz HDMI Stereo Audio & Jaren '80 Retro PSG Synthesizer (`$A030-$A038` & `PLOT 210..213`):**
  * Volwaardige **HDMI 1.4a L-PCM Stereo Audio (48.000 Hz, 16-bit)** rechtstreeks over dezelfde HDMI-kabel naar je TV of monitor (`N=6144, CTS=74250`)!
  * **3 Toonkanalen (Blokgolf/Pulse met Stereo-Panning) + 1 LFSR Ruis/Drum/Explosie-kanaal** (geïnspireerd op de BBC Micro SN76489).
  * **Hardware Envelope & Pitch-Sweep Engine (100 Hz):** ondersteunt automatische volume-decay (`bit 7`), snelle staccato-decay (`bit 6`), **Arcade Laser Pitch-Sweep omlaag** (`bit 5`) en **Power-Up/Jump Pitch-Sweep omhoog** (`bit 4`) — zonder CPU-belasting!
  * **Automatische Arcade Geluidseffecten bij Sprite-Botsingen (`$A038`):** elke biljart-botsing tussen aliens en elke speler-hit laat automatisch live laser-boings en explosies horen over HDMI!
* **📺 80×41 Kleuren Tekst-Terminal met Jaren '70 CRT Hardware-Scrolling:**
  * 8×8 font (2× geschaald naar 16×16 pixels op 1280×720p HDMI).
  * Echte **CRT Hardware-Scrolling (`scroll_offset`)**: zodra de cursor onderaan het scherm komt en je op Enter drukt, schuift het hele tekstbeeld in 1 kloktik omhoog en wordt de onderste regel in 3 µs gewist.
* **💾 Dual-Storage Besturingssysteem (4 KB 6502 SD-MOS ROM):**
  * **MicroSD-kaart (SPI Master op `$A010-$A011`):** Ondersteunt SDHC/SDXC-kaarten met een ingebouwd **SuperFloppy Catalogus-bestandssysteem** (32 bestandsslots van elk 32 KB = 1 MB directe retro-opslag).
  * **4 MB Interne SDRAM-Disk & RAM-Expansie (`$A012-$A015`):** Gebruikt de bovenste 4 Megabyte van het 64 Mbit SDRAM (op 74,25 MHz!) als razendsnelle interne RAM-disk (met volledige 32 KB per bestandsslot) én als 4 MB RAM-expansie voor de 6502, waarmee **8 FPGA BSRAM-blokken** zijn vrijgespeeld!
  * **Volledige BBC BASIC & 6502 Machinetaal bestandscommando's:**
    * Programma's: `SAVE "NAAM"`, `LOAD "NAAM"`, `CHAIN "NAAM"`, `*CAT`, `*INFO`, `*WIPE`, `*SDRAM`, `*SD`, `*SSAVE [0..14]`, `*SLOAD [0..14]`
    * Pure 6502 Machinetaal (`$6000`): `*RUN <NAAM>`, `*BRUN <NAAM>`, `*BLOAD <NAAM>`, `*BSAVE <NAAM>`
    * Databestanden (Random Access / Streams): `OPENOUT`, `OPENIN`, `OPENUP`, `PRINT#`, `INPUT#`, `BPUT#`, `BGET#`, `EOF#`, `PTR#`, `EXT#`, `CLOSE#`.
* **⌨️ Zelfstandig werken met PS/2-Toetsenbord + PC-Terminal:**
  * Hardware PS/2-toetsenbordcontroller (`ps2_keyboard.v`) voor de **Olimex PS/2-module** (pinnen 73 & 74), gelijktijdig te gebruiken met de USB-UART serieel-terminal (115200 baud).

---

## 🗺️ Geheugenindeling (6502 Memory Map)

| Adresbereik | Grootte | Beschrijving |
| :--- | :--- | :--- |
| **`$0000 - $00FF`** | 256 B | **Zero Page** (BBC BASIC II + SD-MOS variabelen `$E0-$EF`) |
| **`$0100 - $01FF`** | 256 B | **6502 Hardware Stack** |
| **`$0200 - $07FF`** | 1,5 KB | **MOS & BBC BASIC Systeemwerkruimte** (`$02D0-$02DF` = Sprite Physics, `$02F5` = `BG_MODE`, `$02F6-$02F7` = `USR_BGV`) |
| **`$0800 - $5FFF`** | **22 KB** | **BBC BASIC Programma-geheugen (`PAGE = $0800`)** |
| **`$6000 - $79FF`** | **6,5 KB** | **Pure 6502 Machinetaal / Binary werkgebied (`*RUN`, `*BLOAD`, `*BSAVE`)** |
| **`$7A00 - $7BFF`** | 512 B | **`FILE_BUF`**: Stream-buffer voor `OPENIN` / `OPENOUT` (`PRINT#` / `INPUT#`) |
| **`$7C00 - $7DFF`** | 512 B | **`SD_BUF`**: Sector-buffer voor MicroSD SPI & Catalogus |
| **`$7E00 - $7FFF`** | 512 B | **IRQ Buffers** voor UART / PS/2 toetsenbord |
| **`$A000 - $A001`** | 2 B | **6850 ACIA Emulatie**: Status (`$A000`), Toetsenbord-in / GPU VDU-uit (`$A001`) |
| **`$A002`** | 1 B | **Hardware Delay Timer**: Schrijf `N` om de CPU `N × 10 ms` te pauzeren via `RDY` |
| **`$A003`** | 1 B | **100 Hz System Timer (`TIMER_TICKS`)**: Hardware centisecond-klok & IRQ bron voor `TIME` en multitasking |
| **`$A004`** | 1 B | **Live Arcade Joypad / Key-Matrix (`JOYPAD`)**: `bit 0`=Up/W, `1`=Down/S, `2`=Left/A, `3`=Right/D, `4`=Space/Z, `5`=X/Shift/Ctrl, `6`=C/Tab, `7`=Enter/Esc |
| **`$A010 - $A011`** | 2 B | **MicroSD Hardware SPI Controller**: Data (`$A010`), CS & Kloksnelheid (`$A011`) |
| **`$A012 - $A015`** | 4 B | **4 MB Interne SDRAM-Disk**: Adres Laag (`$A012`), Hoog (`$A013`), Data (`$A014`), Bank 0..63 (`$A015`) |
| **`$A020 - $A026`** | 7 B | **Directe Hardware Sprite & Physics Registers**: `SPR_SEL` (`$A020`), `X/Y` (`$A021-$A024`), `ACT` (`$A025`), `SPR_STEP` (`$A026`) |
| **`$A027 - $A02B`** | 5 B | **Sprite Collision, Attribute, Video Mode & Pixel Readback**: `SPR_COLL` (`$A027`), `SPR_BOUNCES` (`$A028`), `SPR_ATTR` (`$A029`), `VID_MODE` (`$A02A`), `FB_PIXEL` (`$A02B`) |
| **`$A030 - $A038`** | 9 B | **4-Kanaals HDMI PSG Geluidschip**: `SND_FREQ0..2` (`$A030-$A032`), `SND_NOISE` (`$A033`), `SND_VOL0..3` (`$A034-$A037` Vol+Envelope/Sweep), `SND_CTRL` (`$A038`) |
| **`$B000 - $BFFF`** | **4 KB** | **Extended SD-MOS 1.70 ROM** (`SD_MOS.asm` / `mos_ext.hex`) |
| **`$C000 - $FFFF`** | **16 KB** | **Acorn BBC BASIC II ROM + MOS Vectoren** (`Basic2.asm` + `SBC_MOS.asm`) |

---

## 🔌 Pinaansluitingen (Tang Nano 20K — `nano20k.cst`)

### Olimex PS/2 Toetsenbord
| Signaal | Tang Nano 20K Pin | Opmerking |
| :--- | :---: | :--- |
| **`ps2_data`** | **Pin 73** | Met interne pull-up (`PULL_MODE=UP`) |
| **`ps2_clk`** | **Pin 74** | Met interne pull-up (`PULL_MODE=UP`) |
| **`VCC` / `GND`** | 3.3V / GND | Voeding voor PS/2-toetsenbord |

### Onboard MicroSD-kaartslot (SPI-modus)
| Signaal | Tang Nano 20K Pin | Functie |
| :--- | :---: | :--- |
| **`sd_clk`** | **Pin 83** | SPI Klok (210 kHz init / 3,375 MHz data) |
| **`sd_mosi`** | **Pin 82** | SPI CMD / MOSI |
| **`sd_miso`** | **Pin 84** | SPI DAT0 / MISO |
| **`sd_cs`** | **Pin 81** | SPI DAT3 / Chip Select |
| **`sd_dat1` / `sd_dat2`** | **Pin 85 / 80** | Hoog gehouden (`1'b1`) met pull-up |

---

## 🚀 Overzicht van BBC BASIC & SD-MOS 1.70 Commando's

### 1. Grafische GPU-commando's, Solid Fill, `GCOL 0..4` XOR, `POINT(X,Y)` & `*SSAVE` / `*SLOAD`
```basic
CLS                              : REM Wis tekstscherm (en reset hardware-scroll)
CLG                              : REM Wis grafisch scherm (SDRAM framebuffer)
COLOUR 2                         : REM Zet tekstkleur (0=Zwart, 1=Rood, 2=Groen, 3=Geel, 4=Blauw, 5=Magenta, 6=Cyaan, 7=Wit)
GCOL 0, 14                       : REM Zet tekenkleur (0..7 = BBC palet, 8..255 = direct 256-kleuren RGB332!)
GCOL 3, 7                        : REM Zet GPU in Hardware XOR-modus (1=OR, 2=AND, 3=XOR, 4=INVERT)
GLINE 100, 100, 500, 400         : REM Teken een lijn (in GCOL 3 XOR: nogmaals tekenen wist de lijn exact!)
RECT 300, 150, 400, 250, 1       : REM Teken een HARDWARE GEVULDE rechthoek (74,25 MHz burst!)
MOVE 300, 150 : PLOT 101, 700, 400 : REM BBC BASIC PLOT 101: Hardware Solid Filled Rectangle
CIRCLE 640, 512, 150, 1          : REM Teken een HARDWARE GEVULDE schijf/planeet (PLOT 198 / PLOT 153)!
MOVE 640, 512 : PLOT 153, 150, 0 : REM BBC BASIC PLOT 153: Hardware Solid Filled Circle / Disc
MOVE 200, 200 : MOVE 600, 200 : PLOT 85, 400, 700 : REM BBC BASIC PLOT 85: Hardware Solid Filled Triangle!
P% = POINT(640, 512)             : REM Lees de exacte pixelkleur op (640,512) terug uit het 8 MB SDRAM!
*SSAVE 1                         : REM Kopieer het hele 1280x1024 scherm in 6 ms naar SDRAM Slot 1 (0..14)!
*SLOAD 1                         : REM Herstel het complete 1280x1024 scherm in 6 ms vanuit SDRAM Slot 1!
VDU 23, 224, &3C, &7E, &F8, &F0, &F8, &7E, &3C, 0 : REM Definieer CHR$(224) als Pac-Man karakter!
PRINT CHR$(224)                  : REM Print jouw eigen 8x8 karakter in elke MODE 0..7!
J% = ADVAL(0)                    : REM Lees het 8-bit Live Arcade Joypad register ($A004) uit!
K% = INKEY(0)                    : REM Non-blocking toetsenbord-check (-1 als geen toets, anders ASCII)
?&A002 = 50                      : REM Wacht exact 500 ms (50 x 10 ms) via de hardware timer
```

### 2. MicroSD, 4 MB SDRAM-Disk & Pure 6502 Machinetaal Commando's
```basic
SAVE "MIJNPROG"                  : REM Sla het huidige BASIC-programma op
LOAD "MIJNPROG"                  : REM Laad een BASIC-programma
*HELP                            : REM Toon overzicht van alle ingebouwde SD-MOS 1.60 commando's
*CAT                             : REM Toon de catalogus (inhoudsopgave)
*INFO                            : REM Toon slotnummer (#00..#0E), naam en exacte grootte in HEX ($XXXX B)
*INFO EXCEL                      : REM Toon bestandsinformatie voor één specifiek bestand
*DRIVE 0                         : REM Kies virtuele Floppy Drive 0 t/m 3 (4 x 15 bestanden op SD én SDRAM!)
*SDRAM                           : REM Schakel over naar de interne 4 MB SDRAM-Disk (74,25 MHz!)
*SD                              : REM Schakel terug naar de MicroSD-kaart
*COPY EXCEL                      : REM Kopieer een bestand rechtstreeks tussen MicroSD en 4 MB SDRAM-Disk!
*RENAME OUD NIEUW                : REM Hernoem een bestand in de catalogus
*DELETE MIJNPROG                 : REM Wis één specifiek bestand uit de catalogus (zonder de rest te wissen)
*TYPE README.TXT                 : REM Toon de tekst-inhoud van een bestand op het scherm
*DUMP B000                       : REM Toon een 64-byte Hex + ASCII geheugendump vanaf een HEX-adres
*BG ON                           : REM Start 16 Multi-Color Hardware Sprites + 64x64 Boss + HDMI Geluid via 100 Hz IRQ!
*BG OFF                          : REM Stop achtergrond-sprites en demp geluid
*WIPE                            : REM Formatteer de volledige catalogus van de huidige drive
*RUN EXCEL                       : REM Start VisiCalc / Mini-Excel 6502 (pure 6502 machinetaal op $6000)!
*RUN MATRIX                      : REM Start de 6502 Radar & Laser demo vanaf SD-kaart
*BLOAD EXCEL                     : REM Laad puur 6502 machinetaal-bestand naar $6000 (zonder te starten)
*BSAVE EXCEL                     : REM Sla 2 KB pure 6502 machinecode vanaf $6000 op
```

#### 🕹️ Retro 6502 Machinetaal Collectie op Virtuele Floppy Drive 1 (`*DRIVE 1`)
Schakel naar Drive 1 met `*DRIVE 1` en start direct een van de **10 klassieke 6502-machinetaalprogramma's** (`ORG $6000`):
| Commando | Bronbestand | Jaar / Inspiratie | Beschrijving |
| :--- | :--- | :---: | :--- |
| **`*RUN WOZMON`** | `wozmon6502.asm` | 1976 | **Steve Wozniak's Apple-1 System Monitor** (`6000.603F`, `3000: ...`, `3000R`, `Q`=stop) |
| **`*RUN CHESS`** | `microchess6502.asm` | 1976 | **Peter Jennings' KIM-1 MicroChess** (8x8 schaakbord + Herdermat-partij & GPU-grid) |
| **`*RUN BREAKOUT`** | `breakout6502.asm` | 1976 | **Wozniak's Little Brick Out / Arcade Breakout** op Terminal + 720p MiniGPU |
| **`*RUN DISASM`** | `disasm6502.asm` | 1976 | **Wozniak & Baum 6502 Disassembler** (decodeert live 6502 opcodes op `$6000`) |
| **`*RUN LIFE`** | `life6502.asm` | 1970/76 | **Conway's Game of Life** (Glider, Blinker & R-pentomino kolonie op 6502 + GPU) |
| **`*RUN MANDEL`** | `mandel6502.asm` | 1980 | **6502 Fixed-Point Mandelbrot Fractal** ($Z = Z^2 + C$ in 3.5 fixed-point + GPU) |
| **`*RUN STARWARS`** | `starwars6502.asm` | 1983 | **Atari/Acorn 3D Vector Trench Run** (Hardware Bresenham lijnen, cirkels & sprite!) |
| **`*RUN PRIMES`** | `primes6502.asm` | 1981 | **BYTE Magazine Sieve of Eratosthenes** (vindt alle 54 priemgetallen t/m 255 + GPU) |
| **`*RUN EXCEL`** | `visicalc6502.asm` | 1979 | **VisiCalc / Mini-Excel 6502 Spreadsheet** (live rij-, kolom- en totaalsommen) |
| **`*RUN MATRIX`** | `matrix6502.asm` | 1982 | **6502 Radar & Laser Vector Demo** op de 720p HDMI MiniGPU |

#### 🎆 Fullscreen BBC BASIC, 3D Solid Fill, Teletekst & HDMI Audio Showcase op Drive 2 (`*DRIVE 2`)
Schakel naar Drive 2 met `*DRIVE 2` en start direct een van de **9 fullscreen (`1280×1024`) BBC BASIC + 3D Solid Fill + `VDU 23` + MODE 0..7 + HDMI Sound demo's**:
| Commando | Beschrijving |
| :--- | :--- |
| **`CHAIN "SOLID3D"`** | **3D Hardware Solid Fill & `VDU 23` Arcade UDG Showcase**: tekent 3D-geschaduwde piramides (`PLOT 85`), gevulde planeten (`CIRCLE ..., 1`), gevulde horizon (`RECT ..., 1`) én eigen `VDU 23` Pac-Man/Ghost/Invader karakters in `MODE 1`! |
| **`CHAIN "TELETEKST"`** | **NOS Teletekst Pagina 101 (`MODE 7`)**: authentieke Teletekst-pagina met dubbele-hoogte koppen (`COLOUR 141`), gekleurde balken (`COLOUR 129..133`) en `2×3` Sixel-mozaïeken (`CHR$(191)`/`CHR$(255)`)! |
| **`CHAIN "MODES"`** | **BBC BASIC `MODE 0..7` & Shadow Mode (`MODE 128+n`) Tour**: schakelt live tussen `MODE 2` (`20×20`), `MODE 129` (`40×20` met behoud van 3D graphics!) en `MODE 131` (`80×41` groene fosfor monitor). |
| **`CHAIN "CHIPTUNE"`** | **4-Kanaals 48 kHz HDMI Chiptune & SFX Synthesizer**: demonstreert Laser Zap, Power-Up, Boss-Explosie en een 4-stemmige 80s Chiptune met gevulde GPU Equalizer-balken! |
| **`CHAIN "ALIENWAR"`** | **Hardware Collision, 64×64 Boss & HDMI SFX Demo**: volgt live de `64×64` Rode Mega-Boss (`Sprite 15`), telt live alien-botsingen (`$A028`) en laat elke hit horen over HDMI! |
| **`CHAIN "MULTITASK"`** | **100 Hz IRQ Multitasking Showcase**: draait 3 taken tegelijk (16 Multi-Color Sprites + 100 Hz 6502 teller op `$0900` + 3D MiniGPU Tunnel). |
| **`CHAIN "VUURWERK"`** | **Fullscreen MiniGPU + HDMI Geluid Vuurwerk**: kleurrijke vuurwerk-explosies met knallende HDMI-geluidseffecten over het hele `1280×1024` scherm. |
| **`CHAIN "SYNTHBG"`** | **1984 Synthwave Horizon + Boss Alien**: gevulde 80s neon-zon en 3D-perspectiefgrid met 16 turbo-aliens + `64×64` Mega-Boss + HDMI Audio. |
| **`CHAIN "KLOK"`** | **Fullscreen 100 Hz Hardware Klok & Radar**: 16-staps radar-sweep met sonar-pings aangedreven door de `TIME`-klok (`$A003`). |
| **`CHAIN "BENCHMARK"`** | **27 MHz 6502 vs 1981 BBC Micro Benchmark**: meet BASIC-, 6502 machinetaal- en MiniGPU-snelheid (~15× sneller dan een BBC Micro). |


### 3. Databestanden Lezen & Schrijven (`OPENOUT` / `OPENIN` / `CLOSE#`)
```basic
10 F% = OPENOUT("DATA.DAT")
20 PRINT#F%, "Hallo vanaf de 6502!"
30 PRINT#F%, 12345
40 CLOSE#F%
50 F% = OPENIN("DATA.DAT")
60 INPUT#F%, TEKST$, GETAL%
70 CLOSE#F%
80 PRINT TEKST$, GETAL%
```

### 4. Hardware Sprites, Kleuren, Schaling & Botsingsdetectie (`PLOT 200..203` & `$A020..$A029`)
```basic
PLOT 200, 0, 0                   : REM Selecteer Sprite ID 0 (0 t/m 15)
PLOT 201, 1, 0                   : REM Zet Sprite 0 AAN (1 = zichtbaar, 0 = verborgen)
PLOT 202, 640, 512               : REM Zet Sprite 0 op schermpositie X=640, Y=512 (midden van 1280x1024)
PLOT 203, ADRES, KLEUR           : REM Schrijf pixelkleur naar sprite-geheugen (0..255)
?&A020 = 15 : ?&A029 = &21       : REM Maak Sprite 15 een 64x64 Rode Mega-Boss (Scale=2, Kleur=1)
?&A020 = 0  : ?&A029 = &16       : REM Maak Sprite 0 een 16x16 Cyaan Mini-Scout (Scale=1, Kleur=6)
PRINT "Totaal botsingen: "; ?&A028 : REM Lees de hardware alien-tot-alien botsingsteller ($A028)
PRINT "Speler geraakt:   "; ?&A027 : REM Bit 7=1 als Sprite 0 geraakt is, bits 3..0 = vijand-ID!
```

### 5. 🎵 4-Kanaals 48 kHz HDMI Geluidschip (`PLOT 210..213`, `VDU 7` & `$A030..$A038`)
```basic
VDU 7                            : REM Klassieke 1981 BBC Micro 880 Hz Bell Beep over HDMI!
PLOT 210, 120, &8F               : REM Speel noot C5 (120) op Kanaal 0 met automatische Piano-Decay (&8F)
PLOT 210, 220, &AF               : REM Arcade Laser Zap! (Sweep Down &20 + Auto-Decay &80 + Vol 15)
PLOT 211, 80,  &9F               : REM Power-Up / Jump!  (Sweep Up   &10 + Auto-Decay &80 + Vol 15)
PLOT 213, 20,  &8F               : REM Witte Ruis Explosie op Kanaal 3 (Ruis-frequentie 20 + Auto-Decay)
?&A030 = 120 : ?&A031 = 150 : ?&A032 = 180 : REM 3-Stemmig C-Majeur akkoord (4:5:6 harmonische ratio)
?&A034 = &8F : ?&A035 = &8F : ?&A036 = &8F : REM Start alle 3 kanalen tegelijk in Stereo over HDMI!
?&A038 = 1                       : REM Zet automatische Sprite-Botsing Arcade SFX AAN (0=UIT, &80=Mute)
```

### 6. ⚡ BBC Micro-stijl 100 Hz Hardware Interrupt Multitasking (`*BG ON`, `TIME` & `USR_BGV`)
Dankzij de 100 Hz hardware systeemtimer op `$A003` en de directe memory-mapped sprite-registers (`$A020-$A02A`) ondersteunt **SBC02 SD-MOS 1.50** echte hardware interrupt multitasking:
* **Echte 100 Hz `TIME` Systeemklok (in centiseconden):**
  ```basic
  TIME = 0
  FOR I = 1 TO 10000 : NEXT
  PRINT "Verstreken tijd: "; TIME; " centiseconden"
  ```
* **16 Multi-Color Hardware Sprites + 64×64 Boss op de Achtergrond (`*BG ON` / `*BG OFF`):**
  Typ `*BG ON` om alle 16 Hardware Sprites (`0..2` = `16×16` Scouts, `3..14` = `32×32` Fighters, `15` = `64×64` Rode Mega-Boss) gelijktijdig met 50/100 Hz over het volledige scherm te laten vliegen én tegen elkaar te laten biljart-botsen vanuit de 6502 IRQ-handler, terwijl je op de voorgrond gewoon in BBC BASIC typt of programma's draait!
  * Snelheid en richting van elke sprite (`0..15`) staan live in 6502 RAM op `$02D0..$02DF` (`bit 7`=X-richting, `bit 6`=Y-richting, `bits 5..3`=dX, `bits 2..0`=dY).
* **Eigen 6502 Achtergrondtaak koppelen (`USR_BGV` op `$02F6-$02F7`):**
  ```basic
  10 ?&70 = 0
  20 P% = &0900 : [OPT 2 : INC &70 : RTS :]
  30 ?&2F6 = &00 : ?&2F7 = &09 : REM Start 100 Hz achtergrond-routine op $0900!
  40 FOR I = 1 TO 5000 : NEXT
  50 PRINT "Achtergrond-ticks: "; ?&70
  60 ?&2F7 = 0                 : REM Schakel eigen achtergrond-routine weer uit
  ```

### 7. 📺 BBC BASIC `MODE 0..7` & `MODE 7` NOS Teletekst / Ceefax Engine (`VDU 22` & `$A02A`)
Omdat de 8 MB SDRAM Framebuffer en de BRAM Tekst-Terminal volledig buiten het 6502 RAM leven, blijft **`HIMEM = &7A00` (~29 KB vrij BASIC RAM)** in élke `MODE` behouden en kun je in **alle** modes tegelijk `1280×1024` 256-kleuren graphics + 16 Hardware Sprites tekenen!
* **Overzicht van `MODE 0` t/m `MODE 7`:**
  * **`MODE 0`**: `80 × 41` High-Res Workstation Tekst (`16×16` px chars, Witte tekst) + Full Graphics
  * **`MODE 1`**: `40 × 20` Grote Arcade Tekst (`32×32` px chars, **2× Zoom**, Witte tekst) + Full Graphics
  * **`MODE 2`**: `20 × 20` Mega Arcade Scoreboard Tekst (`64×32` px chars, **4× Breed Chunky Font**) + Full Graphics
  * **`MODE 3`**: `80 × 41` 1980s Groene Fosfor Terminal (`COLOUR 2` standaard)
  * **`MODE 4`**: `40 × 20` 2× Grote Amber/Goud Fosfor Monitor (`COLOUR 13` standaard)
  * **`MODE 5`**: `20 × 20` 4× Brede Cyber-Cyaan Arcade Modus (`COLOUR 6` standaard)
  * **`MODE 6`**: `40 × 20` 2× Grote Groene Fosfor Terminal (`COLOUR 2` standaard)
  * **`MODE 7`**: `40 × 20` **NOS Teletekst / Ceefax Modus** met `2×3` Sixel Blok-Graphics (`CHR$(128..255)`), gekleurde achtergrondbalken (`COLOUR 129..136`) en Dubbele-Hoogte Teletekst-koppen (`COLOUR 141`)!
  * **`MODE 128..135` (`MODE 128 + n`, Shadow/Overlay Mode)**: Wisselt van tekst-resolutie (`0..7`) **zónder** de 3D Graphics Framebuffer eronder te wissen!
  * **`?&A02A` (`VID_MODE`)**: Lees de huidige `MODE` (`0..7`) uit of schrijf `?&A02A = 0..7` om live van tekstschaal te wisselen zonder tekst of graphics te wissen!
* **Teletekst Kleurbalken, Dubbele Hoogte & Sixel Blok-Graphics voorbeeld (`CHAIN "TELETEKST"` op Drive 2):**
  ```basic
  MODE 7
  COLOUR 132 : COLOUR 3
  COLOUR 141 : PRINT "  === NOS TELETEKST 101 ===   "
  COLOUR 141 : PRINT "  === NOS TELETEKST 101 ===   "
  COLOUR 129 : COLOUR 7 : PRINT " NIEUWS ";
  COLOUR 128 : COLOUR 3 : PRINT " 27MHz 6502 + MODE 0..7! "
  REM CHR$(128..191) = 64 Aaneengesloten 2x3 Sixel Blokken (CHR$(191) = Vol Blok)
  REM CHR$(192..255) = 64 Gescheiden 2x3 Teletekst Mozaiek Blokken (CHR$(255) = 6 Tegels)
  ```

---

## 🛠️ Zelf Bouwen & Flashen (Gowin EDA)

1. **ROM's Assembleren (optioneel, na wijziging van `SD_MOS.asm` of `Basic2.asm`):**
   ```powershell
   cd BBCBasicSBC02
   .\build_rom.bat
   ```
   Dit genereert `bbcbasic.hex` (16 KB) en `mos_ext.hex` (4 KB) in de hoofdmap.

2. **FPGA Bitstream Synthetiseren:**
   ```powershell
   C:\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe build.tcl
   ```

3. **Flashen naar de Tang Nano 20K:**
   * **Direct testen in SRAM (snel):**
     ```powershell
     C:\Gowin\Gowin_V1.9.12.03_x64\Programmer\bin\programmer_cli.exe --device GW2AR-18C --location 12577 --run 2 --fsFile impl\pnr\MiniGPU.fs
     ```
   * **Permanent in Flash-geheugen branden:**
     ```powershell
     C:\Gowin\Gowin_V1.9.12.03_x64\Programmer\bin\programmer_cli.exe --device GW2AR-18C --location 12577 --run 36 --fsFile impl\pnr\MiniGPU.fs
     ```

---

## 🙏 Credits & Acknowledgements (Dankwoord)

Dit project bouwt voort op het fantastische open-source werk van de volgende ontwikkelaars en pioniers:

* **6502 CPU Core (`src/cpu.v`, `src/ALU.v`):**
  * Geschreven door **Arlet Ottens** — [github.com/Arlet/verilog-6502](https://github.com/Arlet/verilog-6502) *(Fork: [tenij000/verilog-6502](https://github.com/tenij000/verilog-6502))*
* **Acorn BBC BASIC II & SBC02 Port (`BBCBasicSBC02/`):**
  * Originele 6502 BBC BASIC II (1982) door **Acorn Computers / Sophie Wilson**
  * Broncode-reconstructie en documentatie door **J.G. Harston** (`mdfs.net`)
  * BeebAsm / SBC02 port door **David Banks (`hoglet67`)** — [github.com/hoglet67/BBCBasicSBC02](https://github.com/hoglet67/BBCBasicSBC02) *(Fork: [tenij000/BBCBasicSBC02](https://github.com/tenij000/BBCBasicSBC02))*
* **Tang Nano 20K SDRAM Controller (`src/sdram.v`):**
  * Geschreven door **nand2mario (Feng Zhou)** — [github.com/nand2mario/nestang](https://github.com/nand2mario/nestang) *(Fork: [tenij000/nestang](https://github.com/tenij000/nestang))*
* **HDMI 1.4a SystemVerilog Transmitter (`src/hdmi2/`):**
  * Geschreven door **Sameer Puri** — [github.com/hdl-util/hdmi](https://github.com/hdl-util/hdmi) *(Fork: [tenij000/hdmi](https://github.com/tenij000/hdmi))*
* **MiniGPU 2D Engine, 16 Hardware Sprites, CRT Scrolling Terminal, Olimex PS/2 Driver, 6502 SD-MOS & Retro FPGA Sprite Studio PRO:**
  * Ontwikkeld voor dit Tang Nano 20K 6502 Workstation-project door **[tenij000](https://github.com/tenij000)**.
