# 🖥️ Tang Nano 20K — 27 MHz 6502 Retro Workstation & HDMI MiniGPU

Een complete, zelfstandige **8-bit jaren '80 homecomputer op één FPGA** (Sipeed Tang Nano 20K / Gowin GW2AR-18C), aangedreven door een **27,000 MHz 6502 CPU**, **Acorn BBC BASIC II**, een **eigen 4 KB SD-MOS besturingssysteem**, een **Olimex PS/2-toetsenbordinterface** en een **74,25 MHz 720p HDMI 2D MiniGPU** met SDRAM-framebuffer, 16 hardware sprites en een 80×41 kleurenterminal met jaren '70/'80 CRT hardware-scrolling.

---

## ✨ Belangrijkste Kenmerken (Features)

* **⚡ Turbo 6502 Processor (27,000 MHz):**
  * Draait op de systeemklok van 27 MHz (13,5× sneller dan een originele BBC Micro en 27× sneller dan een Commodore 64).
  * Volledige hardware `RDY`-synchronisatie met de GPU, MicroSD-controller, tekst-terminal en hardware delay-timer (`$A002`).
  * Inclusief de legendarische **ingebouwde 6502 Inline Assembler** (`[ ... ]`) van BBC BASIC II.
* **🎨 74,25 MHz 720p HDMI MiniGPU & SDRAM Framebuffer:**
  * Volledig 64 Mbit SDRAM framebuffer met hardware-versnelde 2D-commando's rechtstreeks vanuit BBC BASIC:
    * `GLINE X1, Y1, X2, Y2` (Bresenham hardware lijn-engine)
    * `RECT X, Y, BREEDTE, HOOGTE` (Hardware gevulde rechthoeken)
    * `CIRCLE X, Y, STRAAL` (Midpoint hardware cirkel-engine)
    * `GCOL 0, KLEUR` & `CLG` (8-bit RGB332 / BBC BASIC kleurenpalet)
* **👾 16 Hardware Sprites (16×16, 2× geschaald naar 32×32 pixels):**
  * Onafhankelijke transparante sprite-overlay bovenop de tekst- en framebuffer-laag.
  * Live te bewerken en te testen met de meegeleverde **Retro FPGA Sprite Studio PRO** (`sprite_editor.py`).
* **📺 80×41 Kleuren Tekst-Terminal met Jaren '70 CRT Hardware-Scrolling:**
  * 8×8 font (2× geschaald naar 16×16 pixels op 1280×720p HDMI).
  * Echte **CRT Hardware-Scrolling (`scroll_offset`)**: zodra de cursor onderaan het scherm komt en je op Enter drukt, schuift het hele tekstbeeld in 1 kloktik omhoog en wordt de onderste regel in 3 µs gewist.
* **💾 Dual-Storage Besturingssysteem (4 KB 6502 SD-MOS ROM):**
  * **MicroSD-kaart (SPI Master op `$A010-$A011`):** Ondersteunt SDHC/SDXC-kaarten met een ingebouwd **SuperFloppy Catalogus-bestandssysteem** (32 bestandsslots van elk 32 KB = 1 MB directe retro-opslag).
  * **4 MB Interne SDRAM-Disk & RAM-Expansie (`$A012-$A015`):** Gebruikt de bovenste 4 Megabyte van het 64 Mbit SDRAM (op 74,25 MHz!) als razendsnelle interne RAM-disk (met volledige 32 KB per bestandsslot) én als 4 MB RAM-expansie voor de 6502, waarmee **8 FPGA BSRAM-blokken** zijn vrijgespeeld!
  * **Volledige BBC BASIC & 6502 Machinetaal bestandscommando's:**
    * Programma's: `SAVE "NAAM"`, `LOAD "NAAM"`, `*CAT`, `*WIPE`, `*SDRAM`, `*SD`
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
| **`$0200 - $07FF`** | 1,5 KB | **MOS & BBC BASIC Systeemwerkruimte** |
| **`$0800 - $5FFF`** | **22 KB** | **BBC BASIC Programma-geheugen (`PAGE = $0800`)** |
| **`$6000 - $79FF`** | **6,5 KB** | **Pure 6502 Machinetaal / Binary werkgebied (`*RUN`, `*BLOAD`, `*BSAVE`)** |
| **`$7A00 - $7BFF`** | 512 B | **`FILE_BUF`**: Stream-buffer voor `OPENIN` / `OPENOUT` (`PRINT#` / `INPUT#`) |
| **`$7C00 - $7DFF`** | 512 B | **`SD_BUF`**: Sector-buffer voor MicroSD SPI & Catalogus |
| **`$7E00 - $7FFF`** | 512 B | **IRQ Buffers** voor UART / PS/2 toetsenbord |
| **`$A000 - $A001`** | 2 B | **6850 ACIA Emulatie**: Status (`$A000`), Toetsenbord-in / GPU VDU-uit (`$A001`) |
| **`$A002`** | 1 B | **Hardware Delay Timer**: Schrijf `N` om de CPU `N × 10 ms` te pauzeren via `RDY` |
| **`$A010 - $A011`** | 2 B | **MicroSD Hardware SPI Controller**: Data (`$A010`), CS & Kloksnelheid (`$A011`) |
| **`$A012 - $A015`** | 4 B | **4 MB Interne SDRAM-Disk**: Adres Laag (`$A012`), Hoog (`$A013`), Data (`$A014`), Bank 0..63 (`$A015`) |
| **`$B000 - $BFFF`** | **4 KB** | **Extended SD-MOS ROM** (`SD_MOS.asm` / `mos_ext.hex`) |
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

## 🚀 Overzicht van BBC BASIC & SD-MOS Commando's

### 1. Grafische GPU-commando's
```basic
CLS                              : REM Wis tekstscherm (en reset hardware-scroll)
CLG                              : REM Wis grafisch scherm (SDRAM framebuffer)
COLOUR 2                         : REM Zet tekstkleur (0=Zwart, 1=Rood, 2=Groen, 3=Geel, 4=Blauw, 5=Magenta, 6=Cyaan, 7=Wit)
GCOL 0, 14                       : REM Zet tekenkleur voor de GPU
GLINE 100, 100, 500, 400         : REM Teken een hardware-lijn van (100,100) naar (500,400)
RECT 300, 150, 400, 250          : REM Teken een gevulde rechthoek op (300,150) van 400x250 pixels
CIRCLE 640, 360, 150             : REM Teken een cirkel op middelpunt (640,360) met straal 150
?&A002 = 50                      : REM Wacht exact 500 ms (50 x 10 ms) via de hardware timer
```

### 2. MicroSD, 4 MB SDRAM-Disk & Pure 6502 Machinetaal Commando's
```basic
SAVE "MIJNPROG"                  : REM Sla het huidige BASIC-programma op
LOAD "MIJNPROG"                  : REM Laad een BASIC-programma
*CAT                             : REM Toon de catalogus (inhoudsopgave)
*DRIVE 0                         : REM Kies virtuele Floppy Drive 0 t/m 3 (4 x 15 bestanden op SD én SDRAM!)
*WIPE                            : REM Formatteer de huidige drive-catalogus
*SDRAM                           : REM Schakel over naar de interne 4 MB SDRAM-Disk (74,25 MHz!)
*SD                              : REM Schakel terug naar de MicroSD-kaart
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

### 4. Hardware Sprites aansturen (`PLOT 200..203`)
```basic
PLOT 200, 0, 0                   : REM Selecteer Sprite ID 0 (0 t/m 15)
PLOT 201, 1, 0                   : REM Zet Sprite 0 AAN (1 = zichtbaar, 0 = verborgen)
PLOT 202, 640, 360               : REM Zet Sprite 0 op schermpositie X=640, Y=360
PLOT 203, ADRES, KLEUR           : REM Schrijf pixelkleur naar sprite-geheugen (0..255)
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
