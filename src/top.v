`timescale 1ns / 1ps

module top(
    input  wire       sys_clk,    // 27 MHz built-in clock
    input  wire       s1,         // Button S1
    output wire [2:0] tmds_d_p,   // HDMI Data
    output wire [2:0] tmds_d_n,
    output wire       tmds_clk_p, // HDMI Clock
    output wire       tmds_clk_n,
    input  wire       UART_RXD,
    output wire       UART_TXD,
    input  wire       ps2_data,   // Pin 73 (USB D- / PS/2 Data)
    input  wire       ps2_clk,    // Pin 74 (USB D+ / PS/2 Clock)
    output wire       sd_clk,     // Pin 83 (MicroSD CLK)
    output wire       sd_mosi,    // Pin 82 (MicroSD CMD/MOSI)
    input  wire       sd_miso,    // Pin 84 (MicroSD DAT0/MISO)
    output wire       sd_cs,      // Pin 81 (MicroSD DAT3/CS)
    output wire       sd_dat1,    // Pin 85 (MicroSD DAT1)
    output wire       sd_dat2,    // Pin 80 (MicroSD DAT2)
    output wire [1:0] led,
    
    // SDRAM Physical Pins
    output wire        O_sdram_clk,
    output wire        O_sdram_cke,
    output wire        O_sdram_cs_n,
    output wire        O_sdram_cas_n,
    output wire        O_sdram_ras_n,
    output wire        O_sdram_wen_n,
    inout  wire [31:0] IO_sdram_dq,
    output wire [10:0] O_sdram_addr,
    output wire [1:0]  O_sdram_ba,
    output wire [3:0]  O_sdram_dqm
);

    // --- Clock Generation ---
    wire hclk5;  // 371.25 MHz (720p 5x pixel clock)
    wire hclk;   // 74.25 MHz  (720p pixel clock)
    wire pll_lock;

    gowin_pll_hdmi pll_hdmi (
        .clkin(sys_clk),
        .clkout(hclk5),
        .lock(pll_lock)
    );

    // Proper reset sequence for SDRAM (wait for PLL lock)
    reg [15:0] reset_timer = 0;
    reg rst_n = 0;
    always @(posedge hclk) begin
        if (!pll_lock) begin
            reset_timer <= 0;
            rst_n <= 0;
        end else if (reset_timer != 16'hFFFF) begin
            reset_timer <= reset_timer + 1;
            rst_n <= 0;
        end else begin
            rst_n <= 1;
        end
    end
    
    wire reset = ~rst_n;

    CLKDIV #(.DIV_MODE(5)) div5 (
        .CLKOUT(hclk),
        .HCLKIN(hclk5),
        .RESETN(1'b1), // Do NOT tie to ~reset, otherwise hclk never starts (circular dependency with reset_timer)
        .CALIB(1'b0)
    );

    // --- UART Receiver ---
    wire [7:0] uart_data;
    wire       uart_valid;

    uart_rx #(
        .CLK_FREQ(27_000_000), // Sys clk is 27MHz
        .BAUD_RATE(115200)
    ) uart_inst (
        .clk(sys_clk),
        .reset(reset),
        .rx(UART_RXD),
        .data(uart_data),
        .valid(uart_valid)
    );
    
    // --- UART Transmitter ---
    reg [7:0] term_rx_data_cpu;
    reg       term_rx_valid_cpu;
    
    uart_tx_fifo #(
        .CLK_FREQ(27_000_000), // Sys clk is 27MHz
        .BAUD_RATE(115200)
    ) uart_tx_inst (
        .clk(sys_clk),
        .reset(reset),
        .tx_start(term_rx_valid_cpu), // Pulse when CPU writes to ACIA
        .tx_data(term_rx_data_cpu),   // Data from ACIA write
        .tx(UART_TXD)
    );

    // --- HDMI Output ---
    wire [11:0] cx, cy;
    wire [2:0]  tmds_d;
    wire        tmds_c;

    // --- UART Router (Mode Switch) ---
    // 0 = Terminal (Driven by 6502 CPU), 1 = Framebuffer
    reg uart_mode = 0;
    reg [31:0] magic_seq;
    always @(posedge sys_clk) begin
        if (reset) begin
            uart_mode <= 0;
            magic_seq <= 0;
        end else if (uart_valid) begin
            magic_seq <= {magic_seq[23:0], uart_data};
            if ({magic_seq[23:0], uart_data} == 32'h1B494D47) uart_mode <= 1; // ESC I M G
            if ({magic_seq[23:0], uart_data} == 32'h1B545854) uart_mode <= 0; // ESC T X T
        end
    end
    
    wire fb_rx_valid = uart_valid && (uart_mode == 1);
    
    // --- 6502 CPU & RAM/ROM ---
    wire [15:0] cpu_ab;
    wire [7:0]  cpu_do;
    reg  [7:0]  cpu_di;
    wire        cpu_we;
    
    // Memory (32KB RAM, 4KB Extended MOS ROM, 16KB BBC BASIC ROM)
    reg [7:0] cpu_ram [0:32767];
    reg [7:0] mos_rom [0:4095];
    reg [7:0] cpu_rom [0:16383];
    
    // 4 MB Internal SDRAM-Disk Fallback & RAM Expansion ($A012-$A015)
    reg [7:0]  rd_addr_lo   = 8'h00;
    reg [7:0]  rd_addr_hi   = 8'h00;
    reg [5:0]  rd_addr_bank = 6'h00;
    wire [7:0] rd_dout;
    reg        rd_req_toggle = 1'b0;
    reg        rd_req_we     = 1'b0;
    reg [21:0] rd_req_addr   = 22'd0;
    reg [7:0]  rd_req_wdata  = 8'h00;
    wire       rd_ack_toggle;
    reg [2:0]  rd_ack_sync   = 3'b000;
    wire       rd_busy       = (rd_req_toggle != rd_ack_sync[2]);
    
    initial begin
        $readmemh("mos_ext.hex", mos_rom);
        $readmemh("bbcbasic.hex", cpu_rom);
    end
    
    // --- MicroSD SPI Master ($A010 = Data, $A011 = Control) ---
    reg [1:0]  sd_ctrl = 2'b11; // Bit 0 = CS (1=inactive), Bit 1 = Slow Clock (1=210kHz)
    assign sd_cs   = sd_ctrl[0];
    assign sd_dat1 = 1'b1;
    assign sd_dat2 = 1'b1;
    
    wire       sd_start = cpu_we && (cpu_ab == 16'hA010);
    wire [7:0] sd_rx_data;
    wire       sd_busy;
    
    sd_spi sd_spi_inst (
        .clk(sys_clk),
        .reset(reset),
        .start(sd_start),
        .tx_data(cpu_do),
        .slow_mode(sd_ctrl[1]),
        .rx_data(sd_rx_data),
        .busy(sd_busy),
        .sd_clk(sd_clk),
        .sd_mosi(sd_mosi),
        .sd_miso(sd_miso)
    );
    
    // --- PS/2 Keyboard Receiver (Olimex PS/2 on Pins 73 & 74) ---
    wire [7:0] ps2_ascii_code;
    wire       ps2_ascii_valid;
    reg        ps2_led_toggle = 1'b1;

    ps2_keyboard ps2_inst (
        .clk(sys_clk),
        .reset(reset),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .ascii_code(ps2_ascii_code),
        .ascii_valid(ps2_ascii_valid)
    );

    // UART RX + PS/2 to CPU (CPU reading keyboard)
    reg [7:0] kbd_data;
    reg       kbd_ready;
    
    // ACIA Control Register
    reg [7:0] acia_ctrl = 0;

    // --- BBC BASIC GPU Line Drawer Signals ---
    wire signed [15:0] gpu_x0, gpu_x1;
    wire signed [15:0] gpu_y0, gpu_y1;
    wire [7:0]  gpu_cmd_color;
    wire gpu_start_sys;
    wire gpu_busy_sys;
    wire gpu_is_circle_sys;
    wire gpu_is_clear_sys;

    // --- Hardware Delay Timer ---
    reg [23:0] delay_counter = 0;
    reg delay_active = 0;
    
    always @(posedge sys_clk) begin
        if (reset) begin
            delay_active <= 0;
        end else if (cpu_we && cpu_ab == 16'hA002) begin
            delay_counter <= cpu_do * 24'd270_000; // 1 eenheid = 10ms (bij 27MHz clk)
            delay_active <= (cpu_do != 0);
        end else if (delay_active) begin
            if (delay_counter > 0)
                delay_counter <= delay_counter - 1;
            else
                delay_active <= 0;
        end
    end

    wire term_busy;
    wire cpu_rdy = !delay_active && !gpu_busy_sys && !gpu_start_sys && !sd_busy && !term_busy && !rd_busy;

    // --- 100 Hz Hardware System Timer ($A003) for BBC BASIC TIME & Multitasking IRQ ---
    reg [18:0] sys_timer_cnt = 0;
    reg [7:0]  timer_ticks   = 0;

    always @(posedge sys_clk) begin
        if (reset) begin
            sys_timer_cnt <= 0;
            timer_ticks   <= 0;
        end else begin
            if (sys_timer_cnt == 19'd269_999)
                sys_timer_cnt <= 0;
            else
                sys_timer_cnt <= sys_timer_cnt + 19'd1;

            if (cpu_rdy && !cpu_we && cpu_ab == 16'hA003) begin
                timer_ticks <= (sys_timer_cnt == 19'd269_999) ? 8'd1 : 8'd0;
            end else if (sys_timer_cnt == 19'd269_999) begin
                if (timer_ticks != 8'hFF)
                    timer_ticks <= timer_ticks + 8'd1;
            end
        end
    end

    // --- Direct Memory-Mapped Hardware Sprite Registers ($A020 - $A029) ---
    reg [3:0]  spr_sel = 0;
    reg [7:0]  spr_dir_out = 0;
    reg [7:0]  sp0_coll_reg = 0;
    reg [7:0]  sp_bounce_cnt = 0;
    reg [11:0] sprite_x_reg [0:15];
    reg [11:0] sprite_y_reg [0:15];
    reg        sprite_active_reg [0:15];
    reg [7:0]  sprite_attr_reg [0:15];
    wire [2:0] video_mode;

    // --- 4-Channel 1980s Retro PSG & Hardware Envelope Registers ($A030 - $A038) ---
    reg [7:0]  snd_freq [0:3];
    reg [7:0]  snd_vol  [0:3];
    reg [7:0]  snd_ctrl = 8'h01; // Bit 0 = Hardware Sprite Bounce/Hit Arcade SFX (ON by default)
    reg [2:0]  env_div  = 3'd0;
    
    always @(posedge sys_clk) begin
        rd_ack_sync <= {rd_ack_sync[1:0], rd_ack_toggle};

        // RAM write (0x0000 - 0x7FFF)
        if (cpu_rdy && cpu_we && cpu_ab < 16'h8000) begin
            cpu_ram[cpu_ab[14:0]] <= cpu_do;
        end
        
        // ACIA Control write (0xA000)
        if (cpu_rdy && cpu_we && cpu_ab == 16'hA000) begin
            acia_ctrl <= cpu_do;
        end
        
        // ACIA Data write (0xA001)
        term_rx_valid_cpu <= 0;
        if (cpu_rdy && cpu_we && cpu_ab == 16'hA001) begin
            term_rx_data_cpu <= cpu_do;
            term_rx_valid_cpu <= 1;
        end
        
        // MicroSD Control & 4 MB SDRAM-Disk registers ($A011 - $A015)
        if (cpu_rdy && cpu_we && cpu_ab == 16'hA011) begin
            sd_ctrl <= cpu_do[1:0];
        end
        if (cpu_rdy && cpu_we && cpu_ab == 16'hA012) begin
            rd_addr_lo    <= cpu_do;
            rd_req_addr   <= {rd_addr_bank, rd_addr_hi, cpu_do};
            rd_req_we     <= 1'b0; // Trigger SDRAM Read Prefetch into rd_dout
            rd_req_toggle <= ~rd_req_toggle;
        end
        if (cpu_rdy && cpu_we && cpu_ab == 16'hA013) begin
            rd_addr_hi <= cpu_do;
        end
        if (cpu_rdy && cpu_we && cpu_ab == 16'hA014) begin
            rd_req_addr   <= {rd_addr_bank, rd_addr_hi, rd_addr_lo};
            rd_req_wdata  <= cpu_do;
            rd_req_we     <= 1'b1; // Trigger SDRAM Write
            rd_req_toggle <= ~rd_req_toggle;
        end
        if (cpu_rdy && cpu_we && cpu_ab == 16'hA015) begin
            rd_addr_bank <= cpu_do[5:0];
        end
        
        // ACIA Data read clears status (0xA001)
        if (cpu_rdy && !cpu_we && cpu_ab == 16'hA001) begin
            kbd_ready <= 0;
        end
        
        // If in terminal mode and we get UART data (excluding magic seq), feed to CPU
        // Placed after the read clear so that incoming characters always take precedence
        // Filter out noise (only allow printable ASCII + CR, LF, BS, ESC)
        if (uart_valid && (uart_mode == 0) && (
            (uart_data >= 8'h20 && uart_data < 8'h7F) || 
            uart_data == 8'h0D || uart_data == 8'h0A || 
            uart_data == 8'h08 || uart_data == 8'h1B ||
            uart_data == 8'h43 || uart_data == 8'h57 || 
            uart_data == 8'h63 || uart_data == 8'h77
        )) begin
            kbd_data <= uart_data;
            kbd_ready <= 1;
        end else if (ps2_ascii_valid && (uart_mode == 0)) begin
            kbd_data <= ps2_ascii_code;
            kbd_ready <= 1;
            ps2_led_toggle <= ~ps2_led_toggle;
        end
    end

    // Address decoding for CPU DI (Synchronous for BRAM inference, held when !cpu_rdy)
    always @(posedge sys_clk) begin
        if (cpu_rdy) begin
            if (cpu_ab < 16'h8000) begin
                cpu_di <= cpu_ram[cpu_ab[14:0]];
            end else if (cpu_ab == 16'hA000) begin
                // ACIA Status: Bit 1 = TX Empty, Bit 0 = RX Full
                cpu_di <= {6'b000000, 1'b1, kbd_ready};
            end else if (cpu_ab == 16'hA001) begin
                cpu_di <= kbd_data;
            end else if (cpu_ab == 16'hA003) begin
                cpu_di <= timer_ticks;
            end else if (cpu_ab == 16'hA010) begin
                cpu_di <= sd_rx_data;
            end else if (cpu_ab == 16'hA014) begin
                cpu_di <= rd_dout;
            end else if (cpu_ab == 16'hA020) begin
                cpu_di <= {4'b0000, spr_sel};
            end else if (cpu_ab == 16'hA021) begin
                cpu_di <= sprite_x_reg[spr_sel][7:0];
            end else if (cpu_ab == 16'hA022) begin
                cpu_di <= {4'b0000, sprite_x_reg[spr_sel][11:8]};
            end else if (cpu_ab == 16'hA023) begin
                cpu_di <= sprite_y_reg[spr_sel][7:0];
            end else if (cpu_ab == 16'hA024) begin
                cpu_di <= {4'b0000, sprite_y_reg[spr_sel][11:8]};
            end else if (cpu_ab == 16'hA025) begin
                cpu_di <= {7'b0000000, sprite_active_reg[spr_sel]};
            end else if (cpu_ab == 16'hA026) begin
                cpu_di <= spr_dir_out;
            end else if (cpu_ab == 16'hA027) begin
                cpu_di <= sp0_coll_reg;
            end else if (cpu_ab == 16'hA028) begin
                cpu_di <= sp_bounce_cnt;
            end else if (cpu_ab == 16'hA029) begin
                cpu_di <= sprite_attr_reg[spr_sel];
            end else if (cpu_ab == 16'hA02A) begin
                cpu_di <= {5'b00000, video_mode};
            end else if (cpu_ab >= 16'hA030 && cpu_ab <= 16'hA033) begin
                cpu_di <= snd_freq[cpu_ab[1:0]];
            end else if (cpu_ab >= 16'hA034 && cpu_ab <= 16'hA037) begin
                cpu_di <= snd_vol[cpu_ab[1:0]];
            end else if (cpu_ab == 16'hA038) begin
                cpu_di <= {3'b000, snd_ctrl[0], (snd_vol[3][3:0] != 4'd0), (snd_vol[2][3:0] != 4'd0), (snd_vol[1][3:0] != 4'd0), (snd_vol[0][3:0] != 4'd0)};
            end else if (cpu_ab >= 16'hB000 && cpu_ab < 16'hC000) begin
                cpu_di <= mos_rom[cpu_ab[11:0]]; // B000-BFFF is 4KB Extended MOS ROM
            end else if (cpu_ab >= 16'hC000) begin
                cpu_di <= cpu_rom[cpu_ab[13:0]]; // C000-FFFF is 16KB BBC BASIC ROM
            end else begin
                cpu_di <= 8'hEA; // NOP for unmapped memory
            end
        end
    end

    cpu cpu_inst (
        .clk(sys_clk),
        .reset(reset),
        .AB(cpu_ab),
        .DI(cpu_di),
        .DO(cpu_do),
        .WE(cpu_we),
        .IRQ(kbd_ready | (acia_ctrl[6:5] == 2'b01) | (timer_ticks != 8'd0)),
        .NMI(1'b0),
        .RDY(cpu_rdy)
    );

    wire [3:0]  sprite_id;
    wire [11:0] sprite_x_out;
    wire [11:0] sprite_y_out;
    wire        sprite_active_out;
    wire        sprite_pos_we;
    wire        sprite_active_we;
    wire [7:0]  sprite_waddr;
    wire [7:0]  sprite_wdata;
    wire        sprite_we;
    wire [1:0]  vdu_snd_ch;
    wire [7:0]  vdu_snd_pitch;
    wire [7:0]  vdu_snd_vol;
    wire        vdu_snd_we;

    vdu_parser parser_inst (
        .clk(sys_clk),
        .reset(reset),
        .din(term_rx_data_cpu),
        .valid(term_rx_valid_cpu),
        .draw_x0(gpu_x0),
        .draw_y0(gpu_y0),
        .draw_x1(gpu_x1),
        .draw_y1(gpu_y1),
        .draw_color(gpu_cmd_color),
        .draw_start(gpu_start_sys),
        .draw_is_circle(gpu_is_circle_sys),
        .draw_is_clear(gpu_is_clear_sys),
        .draw_busy(gpu_busy_sys),
        .sprite_id(sprite_id),
        .sprite_x_out(sprite_x_out),
        .sprite_y_out(sprite_y_out),
        .sprite_active_out(sprite_active_out),
        .sprite_pos_we(sprite_pos_we),
        .sprite_active_we(sprite_active_we),
        .sprite_waddr(sprite_waddr),
        .sprite_wdata(sprite_wdata),
        .sprite_we(sprite_we),
        .snd_ch(vdu_snd_ch),
        .snd_pitch(vdu_snd_pitch),
        .snd_vol(vdu_snd_vol),
        .snd_we(vdu_snd_we)
    );
    
    // Cross sys_clk -> hclk domain for start pulse
    reg [2:0] start_sync;
    always @(posedge hclk) begin
        start_sync <= {start_sync[1:0], gpu_start_sys};
    end
    wire gpu_start_hclk = (start_sync[2:1] == 2'b01);
    
    // These signals are completely stable by the time start_sync pulses, 
    // so we can safely read them directly.
    wire gpu_is_circle_hclk = gpu_is_circle_sys;
    wire gpu_is_clear_hclk = gpu_is_clear_sys;
    
    wire gpu_busy_hclk;
    reg [2:0] busy_sync;
    always @(posedge sys_clk) begin
        busy_sync <= {busy_sync[1:0], gpu_busy_hclk};
    end
    assign gpu_busy_sys = busy_sync[2];
    
    wire [9:0] gpu_fb_x;
    wire [8:0] gpu_fb_y;
    wire [7:0] gpu_fb_color;
    wire       gpu_fb_write;
    wire       gpu_fb_ack;

    gpu gpu_inst (
        .clk(hclk),
        .reset(reset),
        .x0(gpu_x0),
        .y0(gpu_y0),
        .x1(gpu_x1),
        .y1(gpu_y1),
        .color(gpu_cmd_color),
        .start(gpu_start_hclk),
        .is_circle(gpu_is_circle_hclk),
        .is_clear(gpu_is_clear_hclk),
        .busy(gpu_busy_hclk),
        .fb_x(gpu_fb_x),
        .fb_y(gpu_fb_y),
        .fb_color(gpu_fb_color),
        .fb_write(gpu_fb_write),
        .fb_ack(gpu_fb_ack)
    );

    // --- Frame Buffer Module ---
    wire [23:0] rgb_bg;

    sdram_framebuffer fb_inst (
        .clk(hclk),
        .rst_n(~reset),
        .rx_data(uart_data),
        .rx_valid(fb_rx_valid),
        .cx(cx),
        .cy(cy),
        .rgb(rgb_bg),
        .gpu_x(gpu_fb_x),
        .gpu_y(gpu_fb_y),
        .gpu_color(gpu_fb_color),
        .gpu_write(gpu_fb_write),
        .gpu_ack(gpu_fb_ack),
        .rd_req_toggle(rd_req_toggle),
        .rd_req_we(rd_req_we),
        .rd_req_addr(rd_req_addr),
        .rd_req_wdata(rd_req_wdata),
        .rd_rdata(rd_dout),
        .rd_ack_toggle(rd_ack_toggle),
        .O_sdram_clk(O_sdram_clk),
        .O_sdram_cke(O_sdram_cke),
        .O_sdram_cs_n(O_sdram_cs_n),
        .O_sdram_cas_n(O_sdram_cas_n),
        .O_sdram_ras_n(O_sdram_ras_n),
        .O_sdram_wen_n(O_sdram_wen_n),
        .IO_sdram_dq(IO_sdram_dq),
        .O_sdram_addr(O_sdram_addr),
        .O_sdram_ba(O_sdram_ba),
        .O_sdram_dqm(O_sdram_dqm)
    );

    // --- Terminal Module ---
    wire [23:0] rgb_term;
    wire term_active;
    wire bell_trig;

    terminal term_inst (
        .clk_pixel(hclk),
        .clk_sys(sys_clk),
        .rst_n(~reset),
        .rx_data(term_rx_data_cpu),
        .rx_valid(term_rx_valid_cpu),
        .cpu_mode_in(cpu_do[2:0]),
        .cpu_mode_we(cpu_rdy && cpu_we && (cpu_ab == 16'hA02A)),
        .video_mode(video_mode),
        .cx(cx),
        .cy(cy),
        .term_rgb(rgb_term),
        .term_active(term_active),
        .term_busy(term_busy),
        .bell_trig(bell_trig)
    );
    
    // --- Hardware Sprite Rendering & Collision Physics (16 Sprites) ---
    wire [11:0] cur_sp_x = sprite_x_reg[spr_sel];
    wire [11:0] cur_sp_y = sprite_y_reg[spr_sel];
    wire [11:0] step_dx  = {8'd0, cpu_do[5:3], 1'b0};
    wire [11:0] step_dy  = {8'd0, cpu_do[2:0], 1'b0};

    // Combinational Sprite-to-Sprite Collision Detector for spr_sel
    reg       sp_peer_hit;
    reg [3:0] sp_peer_id;
    reg       sp_peer_left;
    reg       sp_peer_below;
    integer   k_idx;

    always @(*) begin
        sp_peer_hit   = 1'b0;
        sp_peer_id    = 4'd0;
        sp_peer_left  = 1'b0;
        sp_peer_below = 1'b0;
        for (k_idx = 0; k_idx < 16; k_idx = k_idx + 1) begin
            if ((k_idx[3:0] != spr_sel) && sprite_active_reg[k_idx[3:0]] && sprite_active_reg[spr_sel]) begin
                if ((cur_sp_x + 12'd32 > sprite_x_reg[k_idx[3:0]]) &&
                    (sprite_x_reg[k_idx[3:0]] + 12'd32 > cur_sp_x) &&
                    (cur_sp_y + 12'd42 > sprite_y_reg[k_idx[3:0]]) &&
                    (sprite_y_reg[k_idx[3:0]] + 12'd42 > cur_sp_y)) begin
                    sp_peer_hit   = 1'b1;
                    sp_peer_id    = k_idx[3:0];
                    sp_peer_left  = (cur_sp_x < sprite_x_reg[k_idx[3:0]]);
                    sp_peer_below = (cur_sp_y < sprite_y_reg[k_idx[3:0]]);
                end
            end
        end
    end

    wire eff_dir_x = sp_peer_hit ? sp_peer_left  : cpu_do[7];
    wire eff_dir_y = sp_peer_hit ? sp_peer_below : cpu_do[6];

    integer i, s_idx;
    always @(posedge sys_clk) begin
        if (reset) begin
            spr_sel       <= 0;
            spr_dir_out   <= 0;
            sp0_coll_reg  <= 0;
            sp_bounce_cnt <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                sprite_x_reg[i]      <= 0;
                sprite_y_reg[i]      <= 0;
                sprite_active_reg[i] <= 0;
                sprite_attr_reg[i]   <= 0;
            end
            // Classic 1981 Acorn BBC Micro Power-On Boot Beep on Channel 0!
            snd_freq[0] <= 8'd200; // 880 Hz (A5)
            snd_vol[0]  <= 8'h8D;  // Vol 13 + Smooth Auto-Decay
            snd_freq[1] <= 8'd0;
            snd_vol[1]  <= 8'd0;
            snd_freq[2] <= 8'd0;
            snd_vol[2]  <= 8'd0;
            snd_freq[3] <= 8'd0;
            snd_vol[3]  <= 8'd0;
            snd_ctrl    <= 8'h01;  // Enable Sprite Bounce/Hit Arcade SFX by default
            env_div     <= 3'd0;
        end else begin
            // 100 Hz Hardware Envelope & Pitch-Sweep Engine
            if (sys_timer_cnt == 19'd269_999) begin
                env_div <= (env_div == 3'd5) ? 3'd0 : (env_div + 3'd1);
                for (s_idx = 0; s_idx < 4; s_idx = s_idx + 1) begin
                    if (snd_vol[s_idx][3:0] != 4'd0) begin
                        // Pitch Sweep Down (bit 5 = Laser Zap) or Up (bit 4 = Jump/Coin)
                        if (snd_vol[s_idx][5]) begin
                            if (snd_freq[s_idx] > 8'd10)
                                snd_freq[s_idx] <= snd_freq[s_idx] - 8'd5;
                            else
                                snd_vol[s_idx][3:0] <= 4'd0;
                        end else if (snd_vol[s_idx][4]) begin
                            if (snd_freq[s_idx] < 8'd245)
                                snd_freq[s_idx] <= snd_freq[s_idx] + 8'd5;
                        end
                        // Volume Auto-Decay (bit 7 = Decay Enable, bit 6 = Fast Decay)
                        if (snd_vol[s_idx][7]) begin
                            if ((snd_vol[s_idx][6] && env_div[0]) || (env_div == 3'd5))
                                snd_vol[s_idx][3:0] <= snd_vol[s_idx][3:0] - 4'd1;
                        end
                    end
                end
            end

            // VDU 7 (CHR$(7) Bell) Trigger from Terminal
            if (bell_trig) begin
                snd_freq[0] <= 8'd200; // 880 Hz BBC Micro Bell
                snd_vol[0]  <= 8'h8E;  // Vol 14 + Auto-Decay
            end

            // PLOT 210..213, Pitch, Vol_Env Trigger from VDU Parser
            if (vdu_snd_we) begin
                snd_freq[vdu_snd_ch] <= vdu_snd_pitch;
                snd_vol[vdu_snd_ch]  <= vdu_snd_vol;
            end

            // Clear Sprite 0 collision latch on CPU read of $A027
            if (cpu_rdy && !cpu_we && cpu_ab == 16'hA027) begin
                sp0_coll_reg <= 0;
            end
            // Latch any collision involving Sprite 0 (Player)
            if (sp_peer_hit) begin
                if (spr_sel == 4'd0)
                    sp0_coll_reg <= {1'b1, 3'b000, sp_peer_id};
                else if (sp_peer_id == 4'd0)
                    sp0_coll_reg <= {1'b1, 3'b000, spr_sel};
            end

            if (sprite_pos_we) begin
                sprite_x_reg[sprite_id] <= sprite_x_out;
                sprite_y_reg[sprite_id] <= sprite_y_out;
            end
            if (sprite_active_we) begin
                sprite_active_reg[sprite_id] <= sprite_active_out;
            end
            if (cpu_rdy && cpu_we) begin
                case (cpu_ab)
                    16'hA020: spr_sel <= cpu_do[3:0];
                    16'hA021: sprite_x_reg[spr_sel][7:0]  <= cpu_do;
                    16'hA022: sprite_x_reg[spr_sel][11:8] <= cpu_do[3:0];
                    16'hA023: sprite_y_reg[spr_sel][7:0]  <= cpu_do;
                    16'hA024: sprite_y_reg[spr_sel][11:8] <= cpu_do[3:0];
                    16'hA025: sprite_active_reg[spr_sel]  <= cpu_do[0];
                    16'hA026: begin
                        spr_dir_out[5:0] <= cpu_do[5:0];
                        if (cpu_do[5:0] == 6'd0) begin
                            spr_dir_out[7:6] <= cpu_do[7:6];
                        end else begin
                            if (sp_peer_hit) begin
                                sp_bounce_cnt <= sp_bounce_cnt + 8'd1;
                                // Hardware Arcade Sound Effects on Sprite Collisions (when snd_ctrl[0]=1)
                                if (snd_ctrl[0]) begin
                                    if (spr_sel == 4'd0 || sp_peer_id == 4'd0) begin
                                        // Player Hit! Trigger Crunchy White-Noise Explosion on Ch3
                                        snd_freq[3] <= 8'd24;
                                        snd_vol[3]  <= 8'h8F;
                                    end else begin
                                        // Alien Billiard Bounce! Trigger Arcade Laser/Boing on Ch2
                                        snd_freq[2] <= sprite_attr_reg[spr_sel][5] ? 8'd45 : (8'd85 + {1'b0, spr_sel, 3'b000});
                                        snd_vol[2]  <= 8'hEA;
                                    end
                                end
                            end
                            // Step X with full 1280p screen & sprite-to-sprite bounce (0..1248)
                            if (!eff_dir_x) begin
                                if (cur_sp_x + step_dx >= 12'd1248) begin
                                    sprite_x_reg[spr_sel] <= 12'd1248;
                                    spr_dir_out[7]        <= 1'b1;
                                end else begin
                                    sprite_x_reg[spr_sel] <= cur_sp_x + step_dx;
                                    spr_dir_out[7]        <= 1'b0;
                                end
                            end else begin
                                if (cur_sp_x <= step_dx) begin
                                    sprite_x_reg[spr_sel] <= 12'd0;
                                    spr_dir_out[7]        <= 1'b0;
                                end else begin
                                    sprite_x_reg[spr_sel] <= cur_sp_x - step_dx;
                                    spr_dir_out[7]        <= 1'b1;
                                end
                            end
                            // Step Y with full 1024 BBC BASIC screen & sprite-to-sprite bounce (46..1020)
                            if (!eff_dir_y) begin
                                if (cur_sp_y + step_dy >= 12'd1020) begin
                                    sprite_y_reg[spr_sel] <= 12'd1020;
                                    spr_dir_out[6]        <= 1'b1;
                                end else begin
                                    sprite_y_reg[spr_sel] <= cur_sp_y + step_dy;
                                    spr_dir_out[6]        <= 1'b0;
                                end
                            end else begin
                                if (cur_sp_y <= 12'd46 + step_dy) begin
                                    sprite_y_reg[spr_sel] <= 12'd46;
                                    spr_dir_out[6]        <= 1'b0;
                                end else begin
                                    sprite_y_reg[spr_sel] <= cur_sp_y - step_dy;
                                    spr_dir_out[6]        <= 1'b1;
                                end
                            end
                        end
                    end
                    16'hA027: sp0_coll_reg  <= 8'd0;
                    16'hA028: sp_bounce_cnt <= cpu_do;
                    16'hA029: sprite_attr_reg[spr_sel] <= cpu_do;
                    16'hA030, 16'hA031, 16'hA032, 16'hA033: snd_freq[cpu_ab[1:0]] <= cpu_do;
                    16'hA034, 16'hA035, 16'hA036, 16'hA037: snd_vol[cpu_ab[1:0]]  <= cpu_do;
                    16'hA038: begin
                        snd_ctrl <= cpu_do;
                        if (cpu_do[7]) begin
                            snd_vol[0] <= 8'd0;
                            snd_vol[1] <= 8'd0;
                            snd_vol[2] <= 8'd0;
                            snd_vol[3] <= 8'd0;
                        end
                    end
                endcase
            end
        end
    end

    wire [7:0] sp_color [0:15];
    
    genvar g;
    generate
        for (g = 0; g < 16; g = g + 1) begin : sp_ram_gen
            reg [7:0] ram [0:255];
            
            initial begin
                $readmemh("sprite.hex", ram);
            end
            
            always @(posedge sys_clk) begin
                if (sprite_we && sprite_id == g) begin
                    ram[sprite_waddr] <= sprite_wdata;
                end
            end
            
            wire [11:0] hdmi_sp_x = sprite_x_reg[g];
            wire [17:0] sy_mult   = sprite_y_reg[g] * 45;
            wire [11:0] hdmi_sp_y = 719 - (sy_mult >> 6);
            
            // Scale selector: 00 = 32x32 (2x), 01 = 16x16 (1x Scout), 10/11 = 64x64 (4x Boss)
            wire [1:0]  sp_scale  = sprite_attr_reg[g][5:4];
            wire [6:0]  sp_size   = (sp_scale == 2'b01) ? 7'd16 :
                                    (sp_scale[1])       ? 7'd64 : 7'd32;
            wire [11:0] dx_sp     = cx - hdmi_sp_x;
            wire [11:0] dy_sp     = cy - hdmi_sp_y;
            wire        in_x      = (cx >= hdmi_sp_x) && (dx_sp < {5'd0, sp_size});
            wire        in_y      = (cy >= hdmi_sp_y) && (dy_sp < {5'd0, sp_size});
            
            wire [3:0]  sp_x_idx  = (sp_scale == 2'b01) ? dx_sp[3:0] :
                                    (sp_scale[1])       ? dx_sp[5:2] : dx_sp[4:1];
            wire [3:0]  sp_y_idx  = (sp_scale == 2'b01) ? dy_sp[3:0] :
                                    (sp_scale[1])       ? dy_sp[5:2] : dy_sp[4:1];
            wire [7:0]  sp_addr   = {sp_y_idx, sp_x_idx};
            wire [7:0]  raw_px    = ram[sp_addr];
            wire [3:0]  attr_col  = sprite_attr_reg[g][3:0];
            
            assign sp_color[g] = (sprite_active_reg[g] && in_x && in_y && (raw_px != 8'h00)) ?
                                 ((attr_col != 4'd0) ? {4'd0, attr_col} : raw_px) : 8'h00;
        end
    endgenerate
    
    wire [7:0] final_sp_color;
    assign final_sp_color = (sp_color[15] != 0) ? sp_color[15] :
                            (sp_color[14] != 0) ? sp_color[14] :
                            (sp_color[13] != 0) ? sp_color[13] :
                            (sp_color[12] != 0) ? sp_color[12] :
                            (sp_color[11] != 0) ? sp_color[11] :
                            (sp_color[10] != 0) ? sp_color[10] :
                            (sp_color[9] != 0)  ? sp_color[9]  :
                            (sp_color[8] != 0)  ? sp_color[8]  :
                            (sp_color[7] != 0)  ? sp_color[7]  :
                            (sp_color[6] != 0)  ? sp_color[6]  :
                            (sp_color[5] != 0)  ? sp_color[5]  :
                            (sp_color[4] != 0)  ? sp_color[4]  :
                            (sp_color[3] != 0)  ? sp_color[3]  :
                            (sp_color[2] != 0)  ? sp_color[2]  :
                            (sp_color[1] != 0)  ? sp_color[1]  :
                            (sp_color[0] != 0)  ? sp_color[0]  : 8'h00;
                            
    wire sprite_visible = (final_sp_color != 8'h00);
    
    // 15-Color Vibrant Neon Arcade Sprite Palette
    reg [23:0] sp_rgb;
    always @(*) begin
        case (final_sp_color[3:0])
            4'd0:  sp_rgb = 24'h000000;
            4'd1:  sp_rgb = 24'hFF2020; // 1: Arcade Red
            4'd2:  sp_rgb = 24'h00FF40; // 2: Invader Green
            4'd3:  sp_rgb = 24'hFFFF00; // 3: Laser Yellow
            4'd4:  sp_rgb = 24'h2080FF; // 4: Electric Blue
            4'd5:  sp_rgb = 24'hFF00FF; // 5: Neon Magenta
            4'd6:  sp_rgb = 24'h00FFFF; // 6: Cyber Cyan
            4'd7:  sp_rgb = 24'hFFFFFF; // 7: Pure White
            4'd8:  sp_rgb = 24'hFF8000; // 8: Blaze Orange
            4'd9:  sp_rgb = 24'hFF1493; // 9: Hot Pink
            4'd10: sp_rgb = 24'h80FF00; // 10: Acid Lime
            4'd11: sp_rgb = 24'h00FFAA; // 11: Aquamarine
            4'd12: sp_rgb = 24'hA040FF; // 12: Plasma Purple
            4'd13: sp_rgb = 24'hFFD700; // 13: Royal Gold
            4'd14: sp_rgb = 24'hFF6060; // 14: Coral Crimson
            4'd15: sp_rgb = 24'h40E0D0; // 15: Turquoise
        endcase
    end
    
    // Combine them: Sprite overlays Terminal, Terminal overlays Framebuffer
    wire [23:0] rgb_bg_or_term = (term_active && uart_mode == 0) ? rgb_term : rgb_bg;
    wire [23:0] rgb = sprite_visible ? sp_rgb : rgb_bg_or_term;

    // --- 48.000 kHz HDMI Audio Synthesizer (3 Tone Channels + 1 LFSR Noise Channel) ---
    // Exact fractional clock divider: 74.25 MHz * 8 / 12375 = 48,000.000 Hz (CTS = 74250, N = 6144)
    reg [13:0] audio_clk_cnt = 14'd0;
    reg        clk_audio     = 1'b0;
    reg        audio_tick    = 1'b0;
    reg [15:0] tone_phase [0:2];
    reg [15:0] noise_phase   = 16'd0;
    reg [15:0] lfsr          = 16'hACE1;
    reg [15:0] audio_sample_l = 16'd0;
    reg [15:0] audio_sample_r = 16'd0;

    wire [6:0]  n_rate = (snd_freq[3][6:0] == 7'd0) ? 7'd16 : snd_freq[3][6:0];
    wire [16:0] n_next = {1'b0, noise_phase} + {6'd0, n_rate, 4'b0000};

    wire signed [5:0] s_ch0 = (snd_freq[0] != 8'd0 && snd_vol[0][3:0] != 4'd0) ?
                              (tone_phase[0][15] ? $signed({2'b00, snd_vol[0][3:0]}) : -$signed({2'b00, snd_vol[0][3:0]})) : 6'sd0;
    wire signed [5:0] s_ch1 = (snd_freq[1] != 8'd0 && snd_vol[1][3:0] != 4'd0) ?
                              (tone_phase[1][15] ? $signed({2'b00, snd_vol[1][3:0]}) : -$signed({2'b00, snd_vol[1][3:0]})) : 6'sd0;
    wire signed [5:0] s_ch2 = (snd_freq[2] != 8'd0 && snd_vol[2][3:0] != 4'd0) ?
                              (tone_phase[2][15] ? $signed({2'b00, snd_vol[2][3:0]}) : -$signed({2'b00, snd_vol[2][3:0]})) : 6'sd0;
    wire signed [5:0] s_ch3 = (snd_freq[3] != 8'd0 && snd_vol[3][3:0] != 4'd0) ?
                              (lfsr[0]           ? $signed({2'b00, snd_vol[3][3:0]}) : -$signed({2'b00, snd_vol[3][3:0]})) : 6'sd0;

    wire signed [7:0] mix_l = (s_ch0 <<< 1) + s_ch1 + s_ch2 + s_ch3;
    wire signed [7:0] mix_r = s_ch0 + (s_ch1 <<< 1) + s_ch2 + s_ch3;

    always @(posedge hclk) begin
        if (reset) begin
            audio_clk_cnt  <= 14'd0;
            clk_audio      <= 1'b0;
            audio_tick     <= 1'b0;
            tone_phase[0]  <= 16'd0;
            tone_phase[1]  <= 16'd0;
            tone_phase[2]  <= 16'd0;
            noise_phase    <= 16'd0;
            lfsr           <= 16'hACE1;
            audio_sample_l <= 16'd0;
            audio_sample_r <= 16'd0;
        end else begin
            if (audio_clk_cnt >= 14'd12367) begin
                audio_clk_cnt <= audio_clk_cnt - 14'd12367;
                clk_audio     <= 1'b1;
                audio_tick    <= 1'b1;
            end else begin
                audio_clk_cnt <= audio_clk_cnt + 14'd8;
                audio_tick    <= 1'b0;
                if (audio_clk_cnt >= 14'd6184)
                    clk_audio <= 1'b0;
            end

            if (audio_tick) begin
                tone_phase[0] <= (snd_freq[0] == 8'd0) ? 16'd0 : (tone_phase[0] + {6'd0, snd_freq[0], 2'b00} + {7'd0, snd_freq[0], 1'b0});
                tone_phase[1] <= (snd_freq[1] == 8'd0) ? 16'd0 : (tone_phase[1] + {6'd0, snd_freq[1], 2'b00} + {7'd0, snd_freq[1], 1'b0});
                tone_phase[2] <= (snd_freq[2] == 8'd0) ? 16'd0 : (tone_phase[2] + {6'd0, snd_freq[2], 2'b00} + {7'd0, snd_freq[2], 1'b0});
                noise_phase   <= n_next[15:0];
                if (n_next[16]) begin
                    if (snd_freq[3][7])
                        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[12]};
                    else
                        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
                end
                audio_sample_l <= {mix_l, 8'd0};
                audio_sample_r <= {mix_r, 8'd0};
            end
        end
    end

    hdmi #(
        .VIDEO_ID_CODE(4),          // 4 = 720p60 (74.25 MHz)
        .DVI_OUTPUT(1'b0),          // True HDMI 1.4a mode with Audio Data Island Packets!
        .VIDEO_REFRESH_RATE(60.0),  // 60.00 Hz refresh rate for exact 74.25 MHz pixel clock
        .AUDIO_RATE(48000),         // 48.0 kHz Stereo L-PCM Audio
        .AUDIO_BIT_WIDTH(16)
    ) hdmi_inst (
        .clk_pixel_x5(hclk5),
        .clk_pixel(hclk),
        .clk_audio(clk_audio),
        .reset(reset),
        .rgb(rgb),
        .audio_sample_word('{audio_sample_r, audio_sample_l}),
        .tmds(tmds_d),
        .tmds_clock(tmds_c),
        .cx(cx),
        .cy(cy),
        .frame_width(),
        .frame_height(),
        .screen_width(),
        .screen_height()
    );

    // Gowin LVDS output buffers for TMDS
    ELVDS_OBUF tmds_bufds [3:0] (
        .I({tmds_c, tmds_d}),
        .O({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n})
    );

    // LEDs for status
    assign led[0] = ps2_led_toggle; // Toggles on every PS/2 keypress!
    assign led[1] = ~pll_lock;      // LED1 ON when PLL is not locked



endmodule
