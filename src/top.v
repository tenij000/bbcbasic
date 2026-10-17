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
    
    // 16KB Internal FPGA-Disk Fallback (BSRAM)
    reg [7:0] ramdisk [0:16383];
    reg [7:0] rd_addr_lo = 8'h00;
    reg [5:0] rd_addr_hi = 6'h00;
    reg [7:0] rd_dout    = 8'h00;
    
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
    
    always @(posedge sys_clk) begin
        // RAM write (0x0000 - 0x7FFF)
        if (cpu_we && cpu_ab < 16'h8000) begin
            cpu_ram[cpu_ab[14:0]] <= cpu_do;
        end
        
        // ACIA Control write (0xA000)
        if (cpu_we && cpu_ab == 16'hA000) begin
            acia_ctrl <= cpu_do;
        end
        
        // ACIA Data write (0xA001)
        term_rx_valid_cpu <= 0;
        if (cpu_we && cpu_ab == 16'hA001) begin
            term_rx_data_cpu <= cpu_do;
            term_rx_valid_cpu <= 1;
        end
        
        // MicroSD Control & Internal FPGA-Disk registers ($A011 - $A014)
        if (cpu_we && cpu_ab == 16'hA011) begin
            sd_ctrl <= cpu_do[1:0];
        end
        if (cpu_we && cpu_ab == 16'hA012) begin
            rd_addr_lo <= cpu_do;
        end
        if (cpu_we && cpu_ab == 16'hA013) begin
            rd_addr_hi <= cpu_do[5:0];
        end
        if (cpu_we && cpu_ab == 16'hA014) begin
            ramdisk[{rd_addr_hi, rd_addr_lo}] <= cpu_do;
        end
        rd_dout <= ramdisk[{rd_addr_hi, rd_addr_lo}];
        
        // ACIA Data read clears status (0xA001)
        if (!cpu_we && cpu_ab == 16'hA001) begin
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
    wire cpu_rdy = !delay_active && !gpu_busy_sys && !gpu_start_sys && !sd_busy && !term_busy;

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
            end else if (cpu_ab == 16'hA010) begin
                cpu_di <= sd_rx_data;
            end else if (cpu_ab == 16'hA014) begin
                cpu_di <= rd_dout;
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
        .IRQ(kbd_ready | (acia_ctrl[6:5] == 2'b01)),
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
        .sprite_we(sprite_we)
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

    terminal term_inst (
        .clk_pixel(hclk),
        .clk_sys(sys_clk),
        .rst_n(~reset),
        .rx_data(term_rx_data_cpu),
        .rx_valid(term_rx_valid_cpu),
        .cx(cx),
        .cy(cy),
        .term_rgb(rgb_term),
        .term_active(term_active),
        .term_busy(term_busy)
    );
    
    // --- Hardware Sprite Rendering (16 Sprites) ---
    reg [11:0] sprite_x_reg [0:15];
    reg [11:0] sprite_y_reg [0:15];
    reg        sprite_active_reg [0:15];
    
    integer i;
    always @(posedge sys_clk) begin
        if (reset) begin
            for (i = 0; i < 16; i = i + 1) begin
                sprite_x_reg[i] <= 0;
                sprite_y_reg[i] <= 0;
                sprite_active_reg[i] <= 0;
            end
        end else begin
            if (sprite_pos_we) begin
                sprite_x_reg[sprite_id] <= sprite_x_out;
                sprite_y_reg[sprite_id] <= sprite_y_out;
            end
            if (sprite_active_we) begin
                sprite_active_reg[sprite_id] <= sprite_active_out;
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
            wire [17:0] sy_mult = sprite_y_reg[g] * 45;
            wire [11:0] hdmi_sp_y = 719 - (sy_mult >> 6);
            
            wire in_x = (cx >= hdmi_sp_x) && (cx < hdmi_sp_x + 32);
            wire in_y = (cy >= hdmi_sp_y) && (cy < hdmi_sp_y + 32);
            
            wire [3:0] sp_x_idx = (cx - hdmi_sp_x) >> 1;
            wire [3:0] sp_y_idx = (cy - hdmi_sp_y) >> 1;
            wire [7:0] sp_addr = {sp_y_idx, sp_x_idx};
            
            assign sp_color[g] = (sprite_active_reg[g] && in_x && in_y) ? ram[sp_addr] : 8'h00;
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
    
    reg [23:0] sp_rgb;
    always @(*) begin
        case (final_sp_color & 7)
            0: sp_rgb = 24'h000000;
            1: sp_rgb = 24'hFF0000;
            2: sp_rgb = 24'h00FF00;
            3: sp_rgb = 24'hFFFF00;
            4: sp_rgb = 24'h0000FF;
            5: sp_rgb = 24'hFF00FF;
            6: sp_rgb = 24'h00FFFF;
            7: sp_rgb = 24'hFFFFFF;
            default: sp_rgb = 24'hFFFFFF;
        endcase
    end
    
    // Combine them: Sprite overlays Terminal, Terminal overlays Framebuffer
    wire [23:0] rgb_bg_or_term = (term_active && uart_mode == 0) ? rgb_term : rgb_bg;
    wire [23:0] rgb = sprite_visible ? sp_rgb : rgb_bg_or_term;

    hdmi #(
        .VIDEO_ID_CODE(4), // 4 = 720p60
        .DVI_OUTPUT(1)     // Use proper HDMI mode
    ) hdmi_inst (
        .clk_pixel_x5(hclk5),
        .clk_pixel(hclk),
        .clk_audio(hclk),
        .reset(reset),
        .rgb(rgb),
        .audio_sample_word('{default:0}),
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
