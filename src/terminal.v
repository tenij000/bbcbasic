module terminal (
    input clk_pixel, // HDMI pixel clock, for reading memory and drawing
    input clk_sys,   // System clock for writing memory
    input rst_n,

    // UART / VDU write interface
    input [7:0] rx_data,
    input rx_valid,

    // Direct CPU Mode Register interface ($A02A)
    input [2:0] cpu_mode_in,
    input       cpu_mode_we,
    output reg [2:0] video_mode,

    // Screen coordinates from HDMI
    input [11:0] cx,
    input [11:0] cy,
    
    // Output color
    output [23:0] term_rgb,
    output term_active,
    output term_busy,
    output reg bell_trig
);

    // Font ROM (1024 bytes)
    // 128 chars * 8 bytes per char. Address is {char_code[6:0], row[2:0]}
    reg [7:0] font_rom [0:1023];
    initial begin
        $readmemh("font8x8.hex", font_rom);
    end

    // Text buffer RAM (4096 entries of 16-bits each)
    // Bits 7:0   = ASCII character (0..127) or Teletext 2x3 Sixel Mosaic (128..255)
    // Bits 11:8  = Foreground color (0..15)
    // Bits 14:12 = Background color (0..7, set via COLOUR 128..136)
    // Bit  15    = Background opaque flag (1 = draw background bar, 0 = transparent over GPU)
    reg [15:0] text_ram [0:4095];

    // Per-row Double-Height Teletext attribute (00 = Normal, 01 = Top Half, 10 = Bottom Half)
    reg [1:0] row_dh [0:44];
    reg       cur_line_dh_top  = 1'b0;
    reg       prev_line_dh_top = 1'b0;
    reg       just_wrapped     = 1'b0;

    // Dynamic geometry based on BBC BASIC MODE (0..7):
    // MODE 0, 3       : 80x41 (16x16 px chars) - High-Res Workstation Text
    // MODE 1, 4, 6, 7 : 40x20 (32x32 px chars) - 2x Big Arcade & NOS Teletext Mode
    // MODE 2, 5       : 20x20 (64x32 px chars) - 4x Wide Chunky BBC MODE 2 Scoreboard Text
    wire is_80col = (video_mode == 3'd0) || (video_mode == 3'd3);
    wire is_20col = (video_mode == 3'd2) || (video_mode == 3'd5);

    wire [6:0] min_x    = is_80col ? 7'd4  : 7'd1;
    wire [6:0] max_x    = is_80col ? 7'd75 : (is_20col ? 7'd18 : 7'd38);
    wire [5:0] min_y    = is_80col ? 6'd2  : 6'd1;
    wire [5:0] max_y    = is_80col ? 6'd42 : 6'd20;
    wire [5:0] num_rows = is_80col ? 6'd41 : 6'd20;
    wire [6:0] num_cols = max_x - min_x + 7'd1;

    reg [6:0] cursor_x = 7'd4;
    reg [5:0] cursor_y = 6'd2;
    reg [5:0] scroll_offset = 6'd0;

    // Translate logical screen cursor_y to physical RAM row using scroll_offset
    wire [5:0] cur_rel_y = (cursor_y >= min_y) ? (cursor_y - min_y) : 6'd0;
    wire [6:0] cur_scrolled = cur_rel_y + scroll_offset;
    wire [5:0] phys_cursor_y = min_y + ((cur_scrolled >= num_rows) ? (cur_scrolled - num_rows) : cur_scrolled[5:0]);

    reg clearing = 0;
    reg [11:0] clear_addr = 0;
    reg clearing_line = 0;
    reg [6:0] clear_x = 0;

    assign term_busy = clearing | clearing_line;

    wire [6:0] active_write_x = clearing_line ? clear_x : cursor_x;
    wire [11:0] write_addr = (phys_cursor_y << 6) + (phys_cursor_y << 4) + active_write_x;
    
    reg [2:0] skip_count = 0;
    reg [2:0] vdu_state = 0;
    reg [7:0] vdu_x = 0;
    reg [3:0] current_color_reg = 4'd7; // Default to white (7)
    reg [2:0] current_bg_reg    = 3'd0; // Default to black (0)
    reg       current_bg_opaque = 1'b0; // Default to transparent overlay

    // VDU 23 (User-Defined Characters / Custom Font Redefinition)
    reg [6:0]  udg_slot   = 7'd0;
    reg [2:0]  udg_row    = 3'd0;
    reg [31:0] udg_active = 32'd0; // Bitmask for BBC UDG range CHR$(224..255) stored in font_rom slots 0..31
    wire       udg_we     = (!clearing) && (!clearing_line) && rx_valid && (skip_count == 3'd0) && (vdu_state == 3'd6);
    wire [9:0] udg_waddr  = {udg_slot, udg_row};
    wire [7:0] udg_wdata  = {rx_data[0], rx_data[1], rx_data[2], rx_data[3], rx_data[4], rx_data[5], rx_data[6], rx_data[7]};

    always @(posedge clk_sys) begin
        if (udg_we) begin
            font_rom[udg_waddr] <= udg_wdata;
        end
    end

    // Handle incoming characters and mode changes (clk_sys)
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            video_mode <= 3'd0;
            cursor_x <= 7'd4;
            cursor_y <= 6'd2;
            scroll_offset <= 0;
            clearing <= 1; // Clear memory on reset
            clear_addr <= 0;
            clearing_line <= 0;
            clear_x <= 0;
            skip_count <= 0;
            vdu_state <= 0;
            current_color_reg <= 4'd7;
            current_bg_reg <= 3'd0;
            current_bg_opaque <= 1'b0;
            cur_line_dh_top <= 1'b0;
            prev_line_dh_top <= 1'b0;
            just_wrapped <= 1'b0;
            udg_slot <= 7'd0;
            udg_row <= 3'd0;
            udg_active <= 32'd0;
            bell_trig <= 0;
        end else if (clearing) begin
            bell_trig <= 0;
            // Write transparent space with current foreground color
            text_ram[clear_addr] <= {4'h0, current_color_reg, 8'h20};
            if (clear_addr < 12'd45) begin
                row_dh[clear_addr[5:0]] <= 2'b00;
            end
            clear_addr <= clear_addr + 1;
            if (clear_addr == 4095) begin
                clearing <= 0;
            end
        end else if (clearing_line) begin
            bell_trig <= 0;
            // Clear the newly scrolled bottom line (80 columns)
            text_ram[write_addr] <= {4'h0, current_color_reg, 8'h20};
            row_dh[phys_cursor_y] <= 2'b00;
            if (clear_x == 7'd79) begin
                clearing_line <= 0;
                clear_x <= 0;
            end else begin
                clear_x <= clear_x + 1;
            end
        end else begin
            bell_trig <= 0;
            if (cpu_mode_we) begin
                video_mode <= cpu_mode_in;
            end
            if (rx_valid) begin
                if (skip_count > 0) begin
                    skip_count <= skip_count - 1;
                end else if (vdu_state == 3'd1) begin
                    vdu_x <= rx_data;
                    vdu_state <= 3'd2;
                end else if (vdu_state == 3'd2) begin
                    cursor_x <= (vdu_x < num_cols) ? (vdu_x[6:0] + min_x) : min_x;
                    cursor_y <= (rx_data < num_rows) ? (rx_data[5:0] + min_y) : min_y;
                    cur_line_dh_top <= 1'b0;
                    prev_line_dh_top <= 1'b0;
                    just_wrapped <= 1'b0;
                    vdu_state <= 3'd0;
                end else if (vdu_state == 3'd3) begin
                    // VDU 17 (COLOUR) parameter:
                    //   0..15    : Foreground color (0..7 standard BBC, 8..15 Neon Arcade)
                    //   128      : Reset background to transparent/black
                    //   129..135 : Opaque colored background bar (Red, Green, Yellow, Blue, Magenta, Cyan, White)
                    //   136      : Opaque black background bar (masks graphics underneath)
                    //   140      : Normal height text row
                    //   141      : BBC Teletext Double-Height row (auto Top Half on 1st row, Bottom Half on 2nd row!)
                    //   142      : Explicit Double-Height Top Half row
                    //   143      : Explicit Double-Height Bottom Half row
                    if (rx_data < 8'd128) begin
                        current_color_reg <= rx_data[3:0];
                    end else if (rx_data == 8'd128) begin
                        current_bg_reg    <= 3'd0;
                        current_bg_opaque <= 1'b0;
                    end else if (rx_data >= 8'd129 && rx_data <= 8'd135) begin
                        current_bg_reg    <= rx_data[2:0];
                        current_bg_opaque <= 1'b1;
                    end else if (rx_data == 8'd136) begin
                        current_bg_reg    <= 3'd0;
                        current_bg_opaque <= 1'b1;
                    end else if (rx_data == 8'd140) begin
                        row_dh[phys_cursor_y] <= 2'b00;
                        cur_line_dh_top       <= 1'b0;
                    end else if (rx_data == 8'd141) begin
                        if (prev_line_dh_top) begin
                            row_dh[phys_cursor_y] <= 2'b10; // Bottom half
                            cur_line_dh_top       <= 1'b0;
                        end else begin
                            row_dh[phys_cursor_y] <= 2'b01; // Top half
                            cur_line_dh_top       <= 1'b1;
                        end
                    end else if (rx_data == 8'd142) begin
                        row_dh[phys_cursor_y] <= 2'b01;
                        cur_line_dh_top       <= 1'b1;
                    end else if (rx_data == 8'd143) begin
                        row_dh[phys_cursor_y] <= 2'b10;
                        cur_line_dh_top       <= 1'b0;
                    end
                    vdu_state <= 3'd0;
                end else if (vdu_state == 3'd4) begin
                    // VDU 22 (MODE n): Switch BBC BASIC Screen Mode (0..7, or 128..135 overlay mode)
                    video_mode <= rx_data[2:0];
                    if (rx_data[2:0] == 3'd7) begin
                        udg_active <= 32'd0; // Restore full 128 Teletext Sixels on MODE 7 entry
                    end
                    case (rx_data[2:0])
                        3'd3, 3'd6: current_color_reg <= 4'd2;  // Green Phosphor Terminal
                        3'd4:       current_color_reg <= 4'd13; // Amber/Gold Phosphor Monitor
                        3'd5:       current_color_reg <= 4'd6;  // Cyber Cyan Arcade
                        default:    current_color_reg <= 4'd7;  // Pure White (MODE 0, 1, 2, 7)
                    endcase
                    current_bg_reg    <= 3'd0;
                    current_bg_opaque <= 1'b0;
                    cur_line_dh_top   <= 1'b0;
                    prev_line_dh_top  <= 1'b0;
                    just_wrapped      <= 1'b0;
                    clearing          <= 1'b1;
                    clear_addr        <= 12'd0;
                    clearing_line     <= 1'b0;
                    clear_x           <= 7'd0;
                    scroll_offset     <= 6'd0;
                    if (rx_data[2:0] == 3'd0 || rx_data[2:0] == 3'd3) begin
                        cursor_x <= 7'd4;
                        cursor_y <= 6'd2;
                    end else begin
                        cursor_x <= 7'd1;
                        cursor_y <= 6'd1;
                    end
                    vdu_state <= 3'd0;
                end else if (vdu_state == 3'd5) begin
                    // VDU 23, char, b0..b7: Select character slot
                    if (rx_data >= 8'd224) begin
                        udg_slot                 <= {2'b00, rx_data[4:0]};
                        udg_active[rx_data[4:0]] <= 1'b1;
                    end else begin
                        udg_slot <= rx_data[6:0];
                    end
                    udg_row   <= 3'd0;
                    vdu_state <= 3'd6;
                end else if (vdu_state == 3'd6) begin
                    // VDU 23: Receive 8 row bytes (written to font_rom via udg_we)
                    if (udg_row == 3'd7) begin
                        vdu_state <= 3'd0;
                    end else begin
                        udg_row <= udg_row + 3'd1;
                    end
                end else if (rx_data == 8'h1F) begin // VDU 31 (TAB x, y)
                    vdu_state <= 3'd1;
                end else if (rx_data == 8'h11) begin // VDU 17 (COLOUR c)
                    vdu_state <= 3'd3;
                end else if (rx_data == 8'h16) begin // VDU 22 (MODE n)
                    vdu_state <= 3'd4;
                end else if (rx_data == 8'h17) begin // VDU 23 (User-Defined Character, 9 bytes)
                    vdu_state <= 3'd5;
                end else if (rx_data == 8'h19) begin // VDU 25 (PLOT k, x, y)
                    skip_count <= 3'd5;
                end else if (rx_data == 8'h12) begin // VDU 18 (GCOL m, c)
                    skip_count <= 3'd2;
                end else if (rx_data == 8'h07) begin // ASCII 7 (Bell / VDU 7)
                    bell_trig <= 1'b1;
                end else if (rx_data == 8'h0C) begin // ASCII 12 Form Feed (CLS) -> CLEAR SCREEN
                    clearing          <= 1'b1;
                    clear_addr        <= 12'd0;
                    clearing_line     <= 1'b0;
                    clear_x           <= 7'd0;
                    scroll_offset     <= 6'd0;
                    current_bg_reg    <= 3'd0;
                    current_bg_opaque <= 1'b0;
                    cur_line_dh_top   <= 1'b0;
                    prev_line_dh_top  <= 1'b0;
                    just_wrapped      <= 1'b0;
                    cursor_x          <= min_x;
                    cursor_y          <= min_y;
                end else if (rx_data == 8'h0D) begin // CR (Carriage Return)
                    cursor_x <= min_x;
                end else if (rx_data == 8'h0A) begin // LF (Line Feed)
                    if (just_wrapped) begin
                        just_wrapped <= 1'b0;
                    end else begin
                        prev_line_dh_top <= cur_line_dh_top;
                        cur_line_dh_top  <= 1'b0;
                        if (cursor_y >= max_y) begin
                            cursor_y      <= max_y;
                            scroll_offset <= (scroll_offset >= (num_rows - 6'd1)) ? 6'd0 : (scroll_offset + 6'd1);
                            clearing_line <= 1'b1;
                            clear_x       <= 7'd0;
                        end else begin
                            cursor_y <= cursor_y + 6'd1;
                        end
                    end
                end else if (rx_data == 8'h08) begin // Backspace
                    just_wrapped <= 1'b0;
                    if (cursor_x > min_x) cursor_x <= cursor_x - 7'd1;
                end else begin
                    // Write character + foreground color + background attribute to RAM
                    text_ram[write_addr] <= {current_bg_opaque, current_bg_reg, current_color_reg, rx_data};
                    
                    // Advance cursor with automatic line-wrap
                    if (cursor_x >= max_x) begin
                        cursor_x         <= min_x;
                        prev_line_dh_top <= cur_line_dh_top;
                        cur_line_dh_top  <= 1'b0;
                        just_wrapped     <= 1'b1;
                        if (cursor_y >= max_y) begin
                            cursor_y      <= max_y;
                            scroll_offset <= (scroll_offset >= (num_rows - 6'd1)) ? 6'd0 : (scroll_offset + 6'd1);
                            clearing_line <= 1'b1;
                            clear_x       <= 7'd0;
                        end else begin
                            cursor_y <= cursor_y + 6'd1;
                        end
                    end else begin
                        cursor_x     <= cursor_x + 7'd1;
                        just_wrapped <= 1'b0;
                    end
                end
            end
        end
    end

    // 16-Color BBC BASIC & Arcade Palette (0..7 standard BBC colors, 8..15 Neon Arcade colors)
    function [23:0] get_color;
        input [3:0] c;
        begin
            case (c)
                4'd0:  get_color = 24'h000000; // 0: Black
                4'd1:  get_color = 24'hFF0000; // 1: Red
                4'd2:  get_color = 24'h00FF00; // 2: Green
                4'd3:  get_color = 24'hFFFF00; // 3: Yellow
                4'd4:  get_color = 24'h0040FF; // 4: Blue
                4'd5:  get_color = 24'hFF00FF; // 5: Magenta
                4'd6:  get_color = 24'h00FFFF; // 6: Cyan
                4'd7:  get_color = 24'hFFFFFF; // 7: White
                4'd8:  get_color = 24'hFF8000; // 8: Blaze Orange
                4'd9:  get_color = 24'hFF1493; // 9: Hot Pink
                4'd10: get_color = 24'h80FF00; // 10: Acid Lime
                4'd11: get_color = 24'h00FFAA; // 11: Aquamarine
                4'd12: get_color = 24'hA040FF; // 12: Plasma Purple
                4'd13: get_color = 24'hFFD700; // 13: Amber / Royal Gold
                4'd14: get_color = 24'hFF6060; // 14: Coral Crimson
                4'd15: get_color = 24'h40E0D0; // 15: Turquoise
            endcase
        end
    endfunction

    // Read logic for HDMI (clk_pixel)
    // cx is 0..1279, cy is 0..719
    // Scale character grid dynamically according to active BBC MODE:
    // - 80-col (MODE 0, 3)       : 16x16 px per char (cx[10:4], cy[9:4])
    // - 40-col (MODE 1, 4, 6, 7) : 32x32 px per char (cx[10:5], cy[9:5])
    // - 20-col (MODE 2, 5)       : 64x32 px per char (cx[10:6], cy[9:5])
    wire [6:0] char_x  = is_80col ? cx[10:4] : (is_20col ? {2'b00, cx[10:6]} : {1'b0, cx[10:5]});
    wire [5:0] char_y  = is_80col ? cy[9:4]  : {1'b0, cy[9:5]};
    wire [2:0] pixel_x = is_80col ? cx[3:1]  : (is_20col ? cx[5:3] : cx[4:2]);
    wire [2:0] pixel_y = is_80col ? cy[3:1]  : cy[4:2];

    reg [5:0] scroll_offset_pix = 0;
    always @(posedge clk_pixel) begin
        scroll_offset_pix <= scroll_offset;
    end

    wire in_scroll_region = (char_y >= min_y) && (char_y <= max_y);
    wire [5:0] read_rel_y = char_y - min_y;
    wire [6:0] read_scrolled = read_rel_y + scroll_offset_pix;
    wire [5:0] phys_read_y = in_scroll_region ?
        (min_y + ((read_scrolled >= num_rows) ? (read_scrolled - num_rows) : read_scrolled[5:0])) :
        char_y;
    
    wire [11:0] read_addr = (phys_read_y << 6) + (phys_read_y << 4) + char_x;
    
    reg [15:0] current_ram_data;
    reg [7:0]  font_row;
    reg [6:0]  char_x_d1, char_x_d2;
    reg [5:0]  char_y_d1, char_y_d2;
    reg [2:0]  pixel_x_d1, pixel_x_d2;
    reg [2:0]  pixel_y_d1, pixel_y_d2;
    reg [1:0]  row_dh_d1;
    reg [7:0]  current_char_d2;
    reg        is_udg_char_d2;
    reg [3:0]  char_color_d2;
    reg [3:0]  char_bg_d2;

    wire [2:0] eff_pixel_y   = (row_dh_d1 == 2'b01) ? {1'b0, pixel_y_d1[2:1]} :
                               (row_dh_d1 == 2'b10) ? (3'd4 + {1'b0, pixel_y_d1[2:1]}) :
                               pixel_y_d1;
    wire       is_udg_char   = (current_ram_data[7:5] == 3'b111) && udg_active[current_ram_data[4:0]];
    wire [6:0] font_char_idx = is_udg_char ? {2'b00, current_ram_data[4:0]} : current_ram_data[6:0];

    always @(posedge clk_pixel) begin
        // Cycle 1: read character + attributes from text_ram BSRAM
        current_ram_data <= text_ram[read_addr];
        char_x_d1        <= char_x;
        char_y_d1        <= char_y;
        pixel_x_d1       <= pixel_x;
        pixel_y_d1       <= pixel_y;
        row_dh_d1        <= (phys_read_y < 6'd45) ? row_dh[phys_read_y] : 2'b00;

        // Cycle 2: read font_rom BSRAM using effective vertical pixel row
        font_row        <= font_rom[{font_char_idx, eff_pixel_y}];
        current_char_d2 <= current_ram_data[7:0];
        is_udg_char_d2  <= is_udg_char;
        char_color_d2   <= current_ram_data[11:8];
        char_bg_d2      <= current_ram_data[15:12];
        char_x_d2       <= char_x_d1;
        char_y_d2       <= char_y_d1;
        pixel_x_d2      <= pixel_x_d1;
        pixel_y_d2      <= eff_pixel_y;
    end
    
    // Cycle 3: Extract pixel from ASCII/UDG font or 2x3 Teletext Sixel Mosaic (128..255)
    wire sixel_bit = (pixel_y_d2 < 3'd3) ? (pixel_x_d2[2] ? current_char_d2[1] : current_char_d2[0]) :
                     (pixel_y_d2 < 3'd5) ? (pixel_x_d2[2] ? current_char_d2[3] : current_char_d2[2]) :
                                           (pixel_x_d2[2] ? current_char_d2[5] : current_char_d2[4]);
    wire sixel_sep_gap = current_char_d2[6] &&
                         ((pixel_x_d2 == 3'd3) || (pixel_x_d2 == 3'd7) ||
                          (pixel_y_d2 == 3'd2) || (pixel_y_d2 == 3'd4) || (pixel_y_d2 == 3'd7));
    wire sixel_pixel = sixel_bit && !sixel_sep_gap;

    wire use_sixel = current_char_d2[7] && !is_udg_char_d2;
    wire pixel_on  = use_sixel ? sixel_pixel : font_row[pixel_x_d2];
    wire is_cursor = (char_x_d2 == cursor_x) && (char_y_d2 == cursor_y) && in_scroll_region;
    wire bg_opaque = char_bg_d2[3];

    assign term_active = pixel_on | is_cursor | bg_opaque;
    assign term_rgb    = is_cursor ? 24'hFFFFFF :
                         pixel_on  ? get_color(char_color_d2) :
                                     get_color({1'b0, char_bg_d2[2:0]});
    
endmodule
