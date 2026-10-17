;; *************************************************************
;; Extended MOS ROM ($B000 - $BFFF):
;; - GLINE, CIRCLE & RECT hardware GPU commands
;; - Hardware SPI MicroSD / SDHC Driver + FPGA-Disk Fallback
;; - OSFILE (SAVE & LOAD), OSCLI (*CAT, *WIPE)
;; - OSFIND/OSBPUT/OSBGET/OSARGS (OPENIN, OPENOUT, PRINT#, INPUT#, CLOSE#)
;; *************************************************************

USE_XON_XOFF      = 1
USE_NMI_TIMER     = 1
USE_NMI_PRESCALER = 1

ZP_START    = $00e0
pblock      = $00e0
pcopy       = $00e2
bufptr      = $00e2

ZP_TIME     = $00f0
ZP_RX_HEAD  = $00f4
ZP_RX_TAIL  = $00f5
ZP_TX_HEAD  = $00f6
ZP_TX_TAIL  = $00f7
ZP_XOFF     = $00f8
ZP_PRESCALE = $00f9
ZP_X        = $00fa
ZP_Y        = $00fb
ZP_ACC      = $00fc
ZP_ERRPTR   = $00fd
ZP_ESCFLAG  = $00ff
ZP_END      = $00ff

BRKV        = $0202
RX_BUFFER   = $7E00
TX_BUFFER   = $7F00
UART        = $A000

SD_DATA     = $A010
SD_CTRL     = $A011
RD_ADDR_LO  = $A012
RD_ADDR_HI  = $A013
RD_DATA     = $A014

FILE_BUF    = $7A00     ; 512-byte stream buffer for OPENIN / OPENOUT
SD_BUF      = $7C00     ; 512-byte directory / sector buffer

;; Open file state ($02E0 - $02F3)
f_mode      = $02E0     ; $00=closed, $40=OPENIN, $80=OPENOUT, $C0=OPENUP
f_idx       = $02E1     ; Current read/write byte index (0..255)
f_len       = $02E2     ; File byte length (0..255)
f_name      = $02E4     ; 16-byte normalized filename for OPENOUT

;; Zero-page workspace ($00E0 - $00EF, reserved for MOS)
sd_ptr      = $00E0     ; 2 bytes ($E0, $E1)
sd_sec_lo   = $00E2     ; 1 byte
sd_sec_hi   = $00E3     ; 1 byte
sd_type     = $00E4     ; $80 = SDHC, $01 = SDSC, $00 = FPGA-Disk
sd_slot     = $00E5     ; Current slot index (0..15)
sd_free     = $00E6     ; First free slot index ($FF if none)
sd_num_sec  = $00E7     ; Number of 512-byte sectors to transfer
sd_dir_ptr  = $00E8     ; 2 bytes ($E8, $E9) pointer into SD_BUF
sd_ctrl_val = $00EA     ; Shadow of SD_CTRL
sd_retry_lo = $00EB
sd_retry_hi = $00EC
sd_action   = $00ED     ; OSFILE action ($00=SAVE, $FF=LOAD, $80=CLOSE#, $40=OPENIN)

macro DO_INCREMENT_TIME
   INC ZP_TIME
   BNE done
   INC ZP_TIME+1
   BNE done
   INC ZP_TIME+2
   BNE done
   INC ZP_TIME+3
.done
endmacro

;; =============================================================
;; GLINE X1, Y1, X2, Y2
;; =============================================================
.LLINE
   JSR L8821                 \ Evaluate expression (X1)
   JSR L92EE                 \ Confirm numeric and ensure is integer
   JSR LBD94                 \ Stack integer (X1)
   JSR L92DA                 \ Step past comma and evaluate integer (Y1)

   \ Pop X1 to &37..&3A
   LDX #&37: JSR LBE0D

   \ Send VDU 25, 4, X1, Y1
   LDA #25: JSR OSWRCH
   LDA #4: JSR OSWRCH
   LDA &37: JSR OSWRCH
   LDA &38: JSR OSWRCH
   JSR L9456                 \ Send Y1 low
   LDA &2B: JSR OSWRCH       \ Send Y1 high

   \ Now evaluate X2, Y2
   JSR L92DA                 \ Step past comma and evaluate X2
   JSR LBD94                 \ Stack X2
   JSR L92DA                 \ Step past comma and evaluate Y2
   JSR L9852                 \ Check for end of statement

   \ Pop X2 to &37..&3A
   LDX #&37: JSR LBE0D

   \ Send VDU 25, 5, X2, Y2
   LDA #25: JSR OSWRCH
   LDA #5: JSR OSWRCH
   LDA &37: JSR OSWRCH
   LDA &38: JSR OSWRCH
   JSR L9456                 \ Send Y2 low
   LDA &2B: JSR OSWRCH       \ Send Y2 high
   JMP L8B9B                 \ Jump to execution loop

;; =============================================================
;; CIRCLE X, Y, R
;; =============================================================
.LCIRCLE
   JSR L8821                 \ Evaluate expression (X)
   JSR L92EE                 \ Confirm numeric and ensure is integer
   JSR LBD94                 \ Stack integer (X)
   JSR L92DA                 \ Step past comma and evaluate integer (Y)
   JSR LBD94                 \ Stack integer (Y)
   JSR L92DA                 \ Step past comma and evaluate integer (R)
   JSR L9852                 \ Check for end of statement

   \ Pop Y to &3F..&42 and X to &37..&3A
   LDX #&3F: JSR LBE0D
   JSR LBE0B

   \ Send VDU 25, 4, X, Y
   LDA #25: JSR OSWRCH
   LDA #4: JSR OSWRCH
   LDA &37: JSR OSWRCH
   LDA &38: JSR OSWRCH
   LDA &3F: JSR OSWRCH
   LDA &40: JSR OSWRCH

   \ Send VDU 25, 199, R, 0
   LDA #25: JSR OSWRCH
   LDA #199: JSR OSWRCH
   JSR L9456                 \ Send R low
   LDA &2B: JSR OSWRCH       \ Send R high
   LDA #0: JSR OSWRCH        \ Y low
   JSR OSWRCH                \ Y high
   JMP L8B9B                 \ Jump to execution loop

;; =============================================================
;; RECT X, Y, BREEDTE, HOOGTE
;; =============================================================
.LRECT
   JSR L8821                 \ Evaluate expression (X)
   JSR L92EE                 \ Confirm numeric and ensure is integer
   LDA &2A: PHA
   LDA &2B: PHA
   JSR L92DA                 \ Step past comma and evaluate integer (Y)
   LDA &2A: PHA
   LDA &2B: PHA
   JSR L92DA                 \ Step past comma and evaluate integer (W)
   LDA &2A: PHA
   LDA &2B: PHA
   JSR L92DA                 \ Step past comma and evaluate integer (H)
   JSR L9852                 \ Check for end of statement

   \ Pop W ($E4/$E5), Y1 ($E2/$E3), X1 ($E0/$E1)
   PLA: STA $E5
   PLA: STA $E4
   PLA: STA $E3
   PLA: STA $E2
   PLA: STA $E1
   PLA: STA $E0

   \ X2 ($E4/$E5) = X1 + W
   CLC
   LDA $E0: ADC $E4: STA $E4
   LDA $E1: ADC $E5: STA $E5

   \ Y2 ($E6/$E7) = Y1 + H (&2A/&2B)
   CLC
   LDA $E2: ADC &2A: STA $E6
   LDA $E3: ADC &2B: STA $E7

   \ Draw 4 sides using VDU 25, 4 (Move) and VDU 25, 5 (Draw)
   LDA #4: LDX #$E0: LDY #$E2: JSR rect_plot
   LDA #5: LDX #$E4: LDY #$E2: JSR rect_plot
   LDA #5: LDX #$E4: LDY #$E6: JSR rect_plot
   LDA #5: LDX #$E0: LDY #$E6: JSR rect_plot
   LDA #5: LDX #$E0: LDY #$E2: JSR rect_plot
   JMP L8B9B                 \ Jump to execution loop

.rect_plot
   PHA
   LDA #25: JSR OSWRCH
   PLA: JSR OSWRCH
   LDA $00,X: JSR OSWRCH
   LDA $01,X: JSR OSWRCH
   LDA $00,Y: JSR OSWRCH
   LDA $01,Y: JMP OSWRCH

;; =============================================================
;; SPI & SD/SDHC Low-Level Primitives
;; =============================================================
.spi_txrx
   STA SD_DATA
   LDA SD_DATA
   RTS

.spi_ff
   LDA #$FF
   STA SD_DATA
   LDA SD_DATA
   RTS

.sd_deselect
   LDA sd_ctrl_val
   ORA #$01
   STA sd_ctrl_val
   STA SD_CTRL
   JSR spi_ff
   RTS

.sd_select
   JSR spi_ff
   LDA sd_ctrl_val
   AND #$FE
   STA sd_ctrl_val
   STA SD_CTRL
   JSR spi_ff
   RTS

.sd_wait_r1
   LDX #$20
.wait_r1_loop
   JSR spi_ff
   tay
   BPL wait_r1_done
   DEX
   BNE wait_r1_loop
.wait_r1_done
   TYA
   RTS

;; Initialize SD/SDHC card (or fall back to FPGA-Disk if no card)
.sd_init
   LDA #$03                  ; slow_mode = 1, CS = 1
   STA sd_ctrl_val
   STA SD_CTRL
   LDX #$10                  ; 16 bytes = 128 clock pulses with CS=1
.init_clk_loop
   JSR spi_ff
   DEX
   BNE init_clk_loop

   LDA #$08                  ; Try CMD0 up to 8 times
   STA sd_retry_lo
.cmd0_retry
   JSR sd_deselect
   JSR sd_select
   LDA #$40: JSR spi_txrx    ; CMD0
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$95: JSR spi_txrx    ; CRC for CMD0
   JSR sd_wait_r1
   CMP #$01
   BEQ cmd0_ok
   DEC sd_retry_lo
   BNE cmd0_retry

.no_sd_fallback
   LDA #$00                  ; $00 = Use internal 16KB FPGA-Disk
   STA sd_type
   JSR sd_deselect
   RTS

.cmd0_ok
   ; Send CMD8 ($48, $00, $00, $01, $AA, $87)
   JSR sd_deselect
   JSR sd_select
   LDA #$48: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$01: JSR spi_txrx
   LDA #$AA: JSR spi_txrx
   LDA #$87: JSR spi_txrx
   JSR sd_wait_r1
   JSR spi_ff
   JSR spi_ff
   JSR spi_ff
   JSR spi_ff

   ; Loop CMD55 + ACMD41 up to 2048 times
   LDA #$00: STA sd_retry_lo
   LDA #$08: STA sd_retry_hi
.acmd41_loop
   JSR sd_deselect
   JSR sd_select
   LDA #$77: JSR spi_txrx    ; CMD55
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$65: JSR spi_txrx
   JSR sd_wait_r1

   JSR sd_deselect
   JSR sd_select
   LDA #$69: JSR spi_txrx    ; ACMD41 (HCS=1)
   LDA #$40: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$77: JSR spi_txrx
   JSR sd_wait_r1
   CMP #$00
   BEQ acmd41_ok

   DEC sd_retry_lo
   BNE acmd41_loop
   DEC sd_retry_hi
   BNE acmd41_loop
   JMP no_sd_fallback

.acmd41_ok
   ; Read OCR (CMD58) to check CCS bit (SDHC vs SDSC)
   JSR sd_deselect
   JSR sd_select
   LDA #$7A: JSR spi_txrx    ; CMD58
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$00: JSR spi_txrx
   LDA #$FD: JSR spi_txrx
   JSR sd_wait_r1
   JSR spi_ff
   PHA                       ; Save OCR byte 0
   JSR spi_ff
   JSR spi_ff
   JSR spi_ff
   PLA
   AND #$40
   BEQ is_sdsc
   LDA #$80                  ; $80 = SDHC block addressing
   BNE set_sd_type
.is_sdsc
   LDA #$01                  ; $01 = SDSC byte addressing
.set_sd_type
   STA sd_type
   LDA #$01                  ; Switch to fast SPI mode (3.375 MHz), CS=1
   STA sd_ctrl_val
   JSR sd_deselect
   RTS

;; Send CMD17 ($51) or CMD24 ($58) in A for sector (sd_sec_hi:sd_sec_lo)
.sd_send_rw_cmd
   PHA
   JSR sd_deselect
   JSR sd_select
   PLA
   JSR spi_txrx
   LDA sd_type
   BMI rw_sdhc
   ; SDSC: byte address = sector * 512
   LDA sd_sec_lo
   ASL A
   TAX
   LDA sd_sec_hi
   ROL A
   TAY
   LDA #$00: JSR spi_txrx    ; arg3
   TYA:      JSR spi_txrx    ; arg2
   TXA:      JSR spi_txrx    ; arg1
   LDA #$00: JSR spi_txrx    ; arg0
   JMP rw_crc
.rw_sdhc
   LDA #$00:      JSR spi_txrx
   LDA #$00:      JSR spi_txrx
   LDA sd_sec_hi: JSR spi_txrx
   LDA sd_sec_lo: JSR spi_txrx
.rw_crc
   LDA #$FF: JSR spi_txrx
   JMP sd_wait_r1

;; =============================================================
;; Read 512-byte sector from (sd_sec_hi:sd_sec_lo) to (sd_ptr)
;; Advances sd_ptr+1 by 2 and increments (sd_sec_hi:sd_sec_lo)
;; =============================================================
.disk_read_sector
   LDA sd_type
   BNE sd_read_sec
   ; FPGA-Disk Fallback Read
   LDA sd_sec_lo
   ASL A
   STA RD_ADDR_HI
   LDY #$00
.rd_read_p0
   STY RD_ADDR_LO
   LDA RD_DATA
   STA (sd_ptr),Y
   INY
   BNE rd_read_p0
   INC sd_ptr+1
   INC RD_ADDR_HI
.rd_read_p1
   STY RD_ADDR_LO
   LDA RD_DATA
   STA (sd_ptr),Y
   INY
   BNE rd_read_p1
   INC sd_ptr+1
   INC sd_sec_lo
   RTS

.sd_read_sec
   LDA #$51                  ; CMD17 (READ_SINGLE_BLOCK)
   JSR sd_send_rw_cmd
   ; Wait for $FE data token
   LDX #$00
   LDY #$00
.wait_fe_loop
   JSR spi_ff
   CMP #$FE
   BEQ got_fe
   INX
   BNE wait_fe_loop
   INY
   BNE wait_fe_loop
.got_fe
   LDY #$00
.sd_read_p0
   JSR spi_ff
   STA (sd_ptr),Y
   INY
   BNE sd_read_p0
   INC sd_ptr+1
.sd_read_p1
   JSR spi_ff
   STA (sd_ptr),Y
   INY
   BNE sd_read_p1
   INC sd_ptr+1
   JSR spi_ff                ; CRC lo
   JSR spi_ff                ; CRC hi
   JSR sd_deselect
   INC sd_sec_lo
   BNE rd_sec_done
   INC sd_sec_hi
.rd_sec_done
   RTS

;; =============================================================
;; Write 512-byte sector from (sd_ptr) to (sd_sec_hi:sd_sec_lo)
;; Advances sd_ptr+1 by 2 and increments (sd_sec_hi:sd_sec_lo)
;; =============================================================
.disk_write_sector
   LDA sd_type
   BNE sd_write_sec
   ; FPGA-Disk Fallback Write
   LDA sd_sec_lo
   ASL A
   STA RD_ADDR_HI
   LDY #$00
.rd_write_p0
   STY RD_ADDR_LO
   LDA (sd_ptr),Y
   STA RD_DATA
   INY
   BNE rd_write_p0
   INC sd_ptr+1
   INC RD_ADDR_HI
.rd_write_p1
   STY RD_ADDR_LO
   LDA (sd_ptr),Y
   STA RD_DATA
   INY
   BNE rd_write_p1
   INC sd_ptr+1
   INC sd_sec_lo
   RTS

.sd_write_sec
   LDA #$58                  ; CMD24 (WRITE_BLOCK)
   JSR sd_send_rw_cmd
   JSR spi_ff
   JSR spi_ff
   LDA #$FE: JSR spi_txrx    ; Data Start Token
   LDY #$00
.sd_write_p0
   LDA (sd_ptr),Y
   JSR spi_txrx
   INY
   BNE sd_write_p0
   INC sd_ptr+1
.sd_write_p1
   LDA (sd_ptr),Y
   JSR spi_txrx
   INY
   BNE sd_write_p1
   INC sd_ptr+1
   JSR spi_ff                ; Dummy CRC lo
   JSR spi_ff                ; Dummy CRC hi
   JSR spi_ff                ; Data response byte
   ; Wait while card busy (MISO == $00)
   LDX #$00
   LDY #$00
.wait_busy_loop
   JSR spi_ff
   CMP #$FF
   BEQ write_busy_done
   INX
   BNE wait_busy_loop
   INY
   BNE wait_busy_loop
.write_busy_done
   JSR sd_deselect
   INC sd_sec_lo
   BNE wr_sec_done
   INC sd_sec_hi
.wr_sec_done
   RTS

;; =============================================================
;; Directory & Filename Helpers
;; =============================================================
;; Set (sd_sec_hi:sd_sec_lo) to Directory Sector (1023 on SD, 0 on FPGA-Disk)
;; and set sd_ptr = SD_BUF ($7C00)
.setup_dir_sec
   LDA #$00: STA sd_ptr
   LDA #>SD_BUF: STA sd_ptr+1
   LDA sd_type
   BEQ dir_is_fpga
   LDA #$FF: STA sd_sec_lo   ; Sector 1023 ($03FF)
   LDA #$03: STA sd_sec_hi
   RTS
.dir_is_fpga
   LDA #$00: STA sd_sec_lo
   STA sd_sec_hi
   RTS

;; Set (sd_sec_hi:sd_sec_lo) to Data Start Sector for slot in sd_slot
.setup_slot_sec
   LDA sd_type
   BEQ slot_is_fpga
   ; SD Card: Sector = $0400 + (sd_slot * 64)
   LDA sd_slot
   AND #$03
   ASL A: ASL A: ASL A: ASL A: ASL A: ASL A
   STA sd_sec_lo
   LDA sd_slot
   LSR A: LSR A
   CLC
   ADC #$04
   STA sd_sec_hi
   RTS
.slot_is_fpga
   ; FPGA-Disk: Sector = 1 + (sd_slot * 2) (1KB = 2 sectors per slot, 15 slots!)
   LDA sd_slot
   ASL A
   CLC
   ADC #$01
   STA sd_sec_lo
   LDA #$00
   STA sd_sec_hi
   RTS

;; Set sd_dir_ptr ($E8/$E9) to SD_BUF + (sd_slot * 32)
.calc_dir_ptr
   LDA sd_slot
   ASL A: ASL A: ASL A: ASL A: ASL A
   STA sd_dir_ptr
   LDA sd_slot
   LSR A: LSR A: LSR A
   CLC
   ADC #>SD_BUF
   STA sd_dir_ptr+1
   RTS

;; Normalize CR-terminated filename at $0600 to 16 uppercase 0-padded bytes
.norm_filename
   LDY #$00
.norm_loop
   CPY #$10
   BEQ norm_done
   LDA $0600,Y
   CMP #$0D
   BEQ norm_pad
   CMP #'a'
   BCC norm_next
   CMP #'z'+1
   BCS norm_next
   AND #$DF                  ; Convert lowercase to uppercase
   STA $0600,Y
.norm_next
   INY
   BNE norm_loop
.norm_pad
   LDA #$00
.norm_pad_loop
   CPY #$10
   BEQ norm_done
   STA $0600,Y
   INY
   BNE norm_pad_loop
.norm_done
   RTS

;; Check if directory entry at (sd_dir_ptr) has magic "BBC!"
;; Returns Z=1 (BEQ) if valid "BBC!", Z=0 (BNE) if free
.check_entry_magic
   LDY #$00
   LDA (sd_dir_ptr),Y: CMP #'B': BNE magic_no
   INY
   LDA (sd_dir_ptr),Y: CMP #'B': BNE magic_no
   INY
   LDA (sd_dir_ptr),Y: CMP #'C': BNE magic_no
   INY
   LDA (sd_dir_ptr),Y: CMP #'!'
.magic_no
   RTS

;; Check if directory entry at (sd_dir_ptr) matches filename at $0600
;; Returns Z=1 (BEQ) if match
.match_entry_name
   JSR check_entry_magic
   BNE name_no
   LDX #$00
   LDY #$04
.name_cmp_loop
   LDA (sd_dir_ptr),Y
   CMP $0600,X
   BNE name_no
   INY
   INX
   CPX #$10
   BNE name_cmp_loop
   LDA #$00                  ; Z=1
.name_no
   RTS

;; Print null-terminated string from (sd_dir_ptr) or inline helper
.print_storage_tag
   LDA sd_type
   BEQ tag_fpga
   LDX #$00
.tag_sd_loop
   LDA msg_sd_tag,X
   BEQ tag_done
   JSR OSASCI
   INX
   BNE tag_sd_loop
.tag_fpga
   LDX #$00
.tag_fpga_loop
   LDA msg_fpga_tag,X
   BEQ tag_done
   JSR OSASCI
   INX
   BNE tag_fpga_loop
.tag_done
   RTS

.print_fname_0600
   LDY #$00
.pf_loop
   CPY #$10
   BEQ pf_done
   LDA $0600,Y
   BEQ pf_done
   JSR OSASCI
   INY
   BNE pf_loop
.pf_done
   JMP OSNEWL

.msg_sd_tag
   EQUS "[SD-KAART] ", 0
.msg_fpga_tag
   EQUS "[FPGA-DISK] ", 0
.msg_saved
   EQUS "OPGESLAGEN: ", 0
.msg_loaded
   EQUS "INGELADEN: ", 0
.msg_cat_hdr
   EQUS "CATALOGUS:", $0D, 0
.msg_wiped
   EQUS "CATALOGUS GEWIST!", $0D, 0

;; =============================================================
;; OSFILE ($FFDD):
;;   A = $00: SAVE BASIC program (PAGE..TOP)
;;   A = $FF: LOAD BASIC program (to PAGE)
;;   A = $80: Save FILE_BUF ($7A00, length f_len) on CLOSE#
;;   A = $40: Load FILE_BUF ($7A00) on OPENIN
;; =============================================================
.nvosfile
   STA sd_action
   JSR norm_filename
   JMP osfile_common
.osfile_from_buf
   STA sd_action
.osfile_common
   JSR sd_init
   JSR setup_dir_sec
   JSR disk_read_sector      ; Load directory into SD_BUF ($7C00)

   ; Search directory slots 0..14
   LDA #$FF: STA sd_free
   LDA #$00: STA sd_slot
.search_loop
   JSR calc_dir_ptr
   JSR match_entry_name
   BEQ found_existing
   JSR check_entry_magic
   BEQ slot_is_used
   ; Slot is free! Record first free slot
   LDA sd_free
   BPL slot_is_used
   LDA sd_slot
   STA sd_free
.slot_is_used
   INC sd_slot
   LDA sd_slot
   CMP #$0F                  ; 15 slots (0..14)
   BNE search_loop

   ; Not found in directory
   LDA sd_action
   BEQ save_new_slot
   CMP #$80
   BEQ save_new_slot
   CMP #$40
   BEQ openin_not_found
   JMP load_not_found        ; If LOAD ($FF), report File not found!
.openin_not_found
   ; If OPENIN ($40) not found, return A = $00 (channel 0 = not found)
   LDA #$00
   STA f_mode
   RTS

.save_new_slot
   ; For SAVE ($00) or CLOSE# ($80), use first free slot (or slot 0 if full)
   LDA sd_free
   BPL use_free_slot
   LDA #$00
.use_free_slot
   STA sd_slot
   JSR calc_dir_ptr

.found_existing
   LDA sd_action
   BEQ do_save_file
   CMP #$80
   BEQ do_save_file
   JMP do_load_file

.do_save_file
   ;; --- SAVE FILE (BASIC program or OPENOUT stream) ---
   ; Write "BBC!" + 16-byte filename + length into (sd_dir_ptr)
   LDY #$00
   LDA #'B': STA (sd_dir_ptr),Y: INY
   LDA #'B': STA (sd_dir_ptr),Y: INY
   LDA #'C': STA (sd_dir_ptr),Y: INY
   LDA #'!': STA (sd_dir_ptr),Y: INY
   LDX #$00
.copy_fn_to_dir
   LDA $0600,X
   STA (sd_dir_ptr),Y
   INY
   INX
   CPX #$10
   BNE copy_fn_to_dir

   LDA sd_action
   CMP #$80
   BNE save_basic_len
   ; Data file from FILE_BUF ($7A00): length = f_len, 1 sector
   LDA f_len
   STA (sd_dir_ptr),Y        ; Offset 20 = len_lo
   INY
   LDA #$00
   STA (sd_dir_ptr),Y        ; Offset 21 = len_hi
   LDA #$01
   STA sd_num_sec
   BNE write_dir_and_data

.save_basic_len
   ; Length = TOP (&12/&13) - PAGE ($0800)
   LDA &12
   STA (sd_dir_ptr),Y        ; Offset 20 = len_lo
   INY
   LDA &13
   SEC
   SBC &18                   ; &13 - &18 (PAGE high byte = $08)
   STA (sd_dir_ptr),Y        ; Offset 21 = len_hi
   LSR A                     ; Sectors = (len_hi >> 1) + 1
   CLC
   ADC #$01
   STA sd_num_sec

.write_dir_and_data
   ; Write updated Directory Sector back to SD / FPGA-Disk
   JSR setup_dir_sec
   JSR disk_write_sector

   ; Write sectors from PAGE ($0800) or FILE_BUF ($7A00)
   JSR setup_slot_sec
   LDA #$00: STA sd_ptr
   LDA sd_action
   CMP #$80
   BNE save_from_page
   LDA #>FILE_BUF
   BNE save_set_ptr_hi
.save_from_page
   LDA &18
.save_set_ptr_hi
   STA sd_ptr+1
.save_sec_loop
   JSR disk_write_sector
   DEC sd_num_sec
   BNE save_sec_loop

   JSR print_storage_tag
   LDX #$00
.pr_sav
   LDA msg_saved,X
   BEQ pr_sav_done
   JSR OSASCI
   INX
   BNE pr_sav
.pr_sav_done
   JMP print_fname_0600

   ;; --- LOAD FILE (BASIC program or OPENIN stream) ---
.do_load_file
   LDY #$14                  ; Offset 20 = len_lo
   LDA (sd_dir_ptr),Y
   STA f_len
   INY                       ; Offset 21 = len_hi
   LDA (sd_dir_ptr),Y
   LSR A
   CLC
   ADC #$01
   STA sd_num_sec

   JSR setup_slot_sec
   LDA #$00: STA sd_ptr
   LDA sd_action
   CMP #$40
   BNE load_to_page
   LDA #$01: STA sd_num_sec
   LDA #>FILE_BUF: STA sd_ptr+1
   JSR disk_read_sector
   LDA #$01                  ; Return channel handle #1 for OPENIN
   RTS

.load_to_page
   LDA &18:  STA sd_ptr+1    ; Load directly to PAGE ($0800)
.load_sec_loop
   JSR disk_read_sector
   DEC sd_num_sec
   BNE load_sec_loop

   JSR print_storage_tag
   LDX #$00
.pr_lod
   LDA msg_loaded,X
   BEQ pr_lod_done
   JSR OSASCI
   INX
   BNE pr_lod
.pr_lod_done
   JMP print_fname_0600

.load_not_found
   BRK
   EQUB 214
   EQUS "File not found"
   BRK

;; =============================================================
;; OSFIND ($FFCE): OPENIN ($40), OPENOUT ($80), OPENUP ($C0), CLOSE# ($00)
;; =============================================================
.nvosfind
   CMP #$00
   BNE osfind_open
   ; CLOSE#handle: if file was opened for write ($80/$C0), flush FILE_BUF to SD
   LDA f_mode
   BPL close_done
   LDA #$00
   STA f_mode
   LDX #$0F
.copy_fn_back
   LDA f_name,X
   STA $0600,X
   DEX
   BPL copy_fn_back
   LDA #$80
   JMP osfile_from_buf
.close_done
   LDA #$00
   STA f_mode
   RTS

.osfind_open
   STA f_mode
   LDA #$00
   STA f_idx
   JSR norm_filename
   LDA f_mode
   BMI open_for_write
   ; OPENIN ($40): Load file into FILE_BUF ($7A00)
   LDA #$40
   JMP osfile_from_buf
.open_for_write
   LDX #$0F
.save_fn_loop
   LDA $0600,X
   STA f_name,X
   DEX
   BPL save_fn_loop
   LDA #$00
   STA f_len
   LDA #$01                  ; Return channel handle #1
   RTS

;; =============================================================
;; OSBPUT ($FFD4): Write byte in A to open file (preserves A, X, Y)
;; =============================================================
.nvosbput
   STX ZP_X
   LDX f_idx
   STA FILE_BUF,X
   INX
   STX f_idx
   STX f_len
   LDX ZP_X
   CLC
   RTS

;; =============================================================
;; OSBGET ($FFD7): Read byte into A from open file (preserves X, Y)
;; =============================================================
.nvosbget
   STX ZP_X
   LDX f_idx
   CPX f_len
   BCS bget_eof
   LDA FILE_BUF,X
   INX
   STX f_idx
   LDX ZP_X
   CLC
   RTS
.bget_eof
   LDA #$FE
   LDX ZP_X
   SEC
   RTS

;; =============================================================
;; OSARGS ($FFDA): PTR# and EXT#
;; =============================================================
.nvosargs
   PHA
   CMP #$00
   BNE osargs_not_ptr_r
   LDA f_idx
   JMP osargs_store
.osargs_not_ptr_r
   CMP #$01
   BNE osargs_ext
   LDA $00,X
   STA f_idx
   PLA
   RTS
.osargs_ext
   LDA f_len
.osargs_store
   STA $00,X
   LDA #$00
   STA $01,X
   STA $02,X
   STA $03,X
   PLA
   RTS

;; =============================================================
;; OSCLI ($FFF7): *CAT (list files), *WIPE (format directory)
;; =============================================================
.nvoscli
   STX sd_ptr
   STY sd_ptr+1
   LDY #$00
.cli_skip_sp
   LDA (sd_ptr),Y
   CMP #' '
   BEQ cli_next_sp
   CMP #'*'
   BNE cli_check_cmd
.cli_next_sp
   INY
   BNE cli_skip_sp
.cli_check_cmd
   AND #$DF                  ; Uppercase first letter
   CMP #'W'
   BEQ cli_wipe
   ; Default: *CAT (Catalogue)
   JSR sd_init
   JSR setup_dir_sec
   JSR disk_read_sector
   JSR print_storage_tag
   LDX #$00
.pr_cat_h
   LDA msg_cat_hdr,X
   BEQ pr_cat_h_done
   JSR OSASCI
   INX
   BNE pr_cat_h
.pr_cat_h_done
   LDA #$00: STA sd_slot
.cat_slot_loop
   JSR calc_dir_ptr
   JSR check_entry_magic
   BNE cat_next_slot
   LDA #' ': JSR OSASCI
   LDA #'-': JSR OSASCI
   LDA #' ': JSR OSASCI
   LDY #$04
.cat_fn_loop
   CPY #$14
   BEQ cat_fn_done
   LDA (sd_dir_ptr),Y
   BEQ cat_fn_done
   JSR OSASCI
   INY
   BNE cat_fn_loop
.cat_fn_done
   JSR OSNEWL
.cat_next_slot
   INC sd_slot
   LDA sd_slot
   CMP #$0F
   BNE cat_slot_loop
   RTS

.cli_wipe
   JSR sd_init
   ; Clear SD_BUF ($7C00-$7DFF)
   LDA #$00
   TAY
.wipe_p0
   STA SD_BUF,Y
   STA SD_BUF+$100,Y
   INY
   BNE wipe_p0
   JSR setup_dir_sec
   JSR disk_write_sector
   JSR print_storage_tag
   LDX #$00
.pr_wip
   LDA msg_wiped,X
   BEQ pr_wip_done
   JSR OSASCI
   INX
   BNE pr_wip
.pr_wip_done
   RTS

;; =============================================================
;; Standard SBC02 MOS Routines (UART, OSWORD, OSBYTE, IRQ, Reset)
;; =============================================================
.nvosrdch
{
   STX ZP_X
.loop_empty
   LDX ZP_RX_HEAD
   CPX ZP_RX_TAIL
   BEQ loop_empty
   LDA ZP_ESCFLAG
   ROL A
   LDA RX_BUFFER, X
   INC ZP_RX_HEAD
   LDX ZP_X
   RTS
}

.nvoswrch
{
   STX ZP_X
.loop_full
   LDX ZP_TX_TAIL
   INX
   CPX ZP_TX_HEAD
   BEQ loop_full
   STA TX_BUFFER,X
   STX ZP_TX_TAIL
   LDX #$B5
   STX UART
   LDX ZP_X
}

.nvosgbpb
   RTS

.nvosword
{
   PHA
   STX pblock
   STY pblock+1
   TAY
   BEQ osword_readline
   DEY
   BEQ osword_readsysclk
   DEY
   BNE osword_exit

.osword_writesysclk
   LDY #$03
.wloop
   LDA (pblock), Y
   STA ZP_TIME,Y
   DEY
   BPL wloop
   BMI osword_exit

.osword_readsysclk
   LDY #$03
.rloop
   LDA ZP_TIME,Y
   STA (pblock), Y
   DEY
   BPL rloop
IF USE_NMI_TIMER <> 1
   DO_INCREMENT_TIME
ENDIF

.osword_exit
   LDY pblock+1
   PLA
   RTS

.osword_readline
   LDY #&04
.ploop
   LDA (pblock),Y
   STA pcopy,Y
   DEY
   BPL ploop
   INY
   BPL cloop2

.bell
   LDA #&07
.y0
   DEY
.y1
   INY
.cloop1
   JSR OSWRCH
.cloop2
   JSR OSRDCH
   BCS exit_err
   CMP #&08
   BNE not_del
   CPY #&00
   BEQ cloop2
   DEY
   JSR OSWRCH
   LDA #$20
   JSR OSWRCH
   LDA #$08
   BNE cloop1

.not_del
   STA (bufptr),Y
   CMP #&0D
   BEQ exit_ok
   CPY pcopy+2
   BCS bell
   CMP pcopy+3
   BCC y0
   CMP pcopy+4
   BEQ y1
   BCC y1
   BCS y0

.exit_ok
   JSR OSNEWL
.exit_err
   LDA ZP_ESCFLAG
   ROL A
   PLA
   RTS
}

.nvosbyte
{
   PHA
   CMP #$7C
   BNE not7c
.clrescape
   LDA #$00
.setescape
   STA ZP_ESCFLAG
   PLA
   RTS
.not7c
   CMP #$7D
   BNE not7d
   LDA #$80
   BNE setescape
.not7d
   CMP #$7E
   BNE not7e
   LDX #$00
   STX ZP_RX_HEAD
   STX ZP_RX_TAIL
   DEX
   BNE clrescape
.not7e
   CMP #$7F                  ; OSBYTE &7F = EOF# check
   BNE not7f
   LDA f_idx
   CMP f_len
   BCC eof_false
   LDX #$FF
   BNE exit
.eof_false
   LDX #$00
   BEQ exit
.not7f
   CMP #$83
   BNE not83
   LDY #$08
   BNE exitx0
.not83
   CMP #$84
   BNE exit
   LDY #$7A                  ; HIMEM = $7A00 (leaves $7A00-$7BFF for FILE_BUF and $7C00-$7DFF for SD_BUF)
.exitx0
   LDX #$00
.exit
   PLA
   RTS
}

.irqbrk_handler
{
   STA ZP_ACC
   PLA
   PHA
   AND #$10
   BEQ irq_handler
   TXA
   PHA
   TSX
   LDA $103, X
   CLD
   SEC
   SBC #$01
   STA ZP_ERRPTR
   LDA $104, X
   SBC #$00
   STA ZP_ERRPTR+1
   PLA
   TAX
   LDA ZP_ACC
   CLI
   JMP (BRKV)
}

.nmi_handler
{
IF USE_NMI_PRESCALER = 1
   LSR ZP_PRESCALE
   BCC tick
   RTI
.tick
   DEC ZP_PRESCALE
ENDIF
IF USE_NMI_TIMER = 1
   DO_INCREMENT_TIME
ENDIF
   RTI
}

.irq_handler
{
   TXA
   PHA
   LDA UART
   AND #$01
   BEQ irq_tx
   LDA UART+1
   CMP #$1B
   BNE irq_noesc
   LDX #$80
   STX ZP_ESCFLAG
.irq_noesc
   LDX ZP_RX_TAIL
   STA RX_BUFFER,X
   INX
   CPX ZP_RX_HEAD
   BEQ irq_tx
   STX ZP_RX_TAIL

.irq_tx
   LDA UART
   AND #$02
   BEQ irq_exit
IF USE_XON_XOFF = 1
   LDA ZP_RX_TAIL
   SEC
   SBC ZP_RX_HEAD
   EOR ZP_XOFF
   CMP #$C0
   BCC irq_tx_char
   LDA ZP_XOFF
   EOR #$FF
   STA ZP_XOFF
   BNE send_xoff
   LDA #$11
   BNE send_a
.send_xoff
   LDA #$13
   BNE send_a
ENDIF

.irq_tx_char
   LDX ZP_TX_HEAD
   CPX ZP_TX_TAIL
   BEQ irq_tx_done
   INX
   STX ZP_TX_HEAD
   LDA TX_BUFFER, X
.send_a
   STA UART+1
.irq_exit
   PLA
   TAX
   LDA ZP_ACC
   RTI
.irq_tx_done
   LDA #$95
   STA UART
   BNE irq_exit
}

.reset_msg
   EQUB $0D
   EQUS "SBC02 "
   EQUS GITVERSION
   EQUB $0A, $0D
IF USE_XON_XOFF = 1
   EQUB $11
ENDIF
   EQUB $00

.default_brk_handler
.reset_handler
{
   CLD
   LDX #$FF
   TXS
   LDA #<default_brk_handler
   STA BRKV
   LDA #>default_brk_handler
   STA BRKV + 1
   INX
   STX f_mode
   LDY #ZP_END - ZP_START + 1
.clrloop
   STX ZP_START - 1, Y
   DEY
   BNE clrloop
   LDA #<reset_msg
   STA ZP_ERRPTR
   LDA #>reset_msg
   STA ZP_ERRPTR + 1
   LDA #$95
   STA UART
   CLI
.prloop
   LDA reset_msg, Y
   BEQ done
   JSR OSASCI
   INY
   BNE prloop
.done
   JMP ENTER_BASIC
}

