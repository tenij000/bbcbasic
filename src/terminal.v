module terminal (
    input clk_pixel, // HDMI pixel clock, for reading memory and drawing
    input clk_sys,   // System clock for writing memory
    input rst_n,

    // UART write interface
    input [7:0] rx_data,
    input rx_valid,

    // Screen coordinates from HDMI
    input [11:0] cx,
    input [11:0] cy,
    
    // Output color
    output [23:0] term_rgb,
    output term_active,
    output term_busy
);

    // Font ROM (1024 bytes)
    // 128 chars * 8 bytes per char. Address is {char_code[6:0], row[2:0]}
    reg [7:0] font_rom [0:1023];
    initial begin
        $readmemh("font8x8.hex", font_rom);
    end

    // Text buffer RAM (4096 entries of 16-bits each)
    // Bits 7:0 = ASCII character, Bits 11:8 = foreground color
    // Dual port RAM: Port A (write from UART), Port B (read from HDMI)
    reg [15:0] text_ram [0:4095];
    
    // Cursor position and Margins to avoid monitor overscan
    parameter MARGIN_LEFT = 4;
    parameter MARGIN_RIGHT = 4;
    parameter MARGIN_TOP = 2;
    parameter MARGIN_BOTTOM = 2;
    parameter MAX_X = 79 - MARGIN_RIGHT;
    parameter MAX_Y = 44 - MARGIN_BOTTOM;
    parameter NUM_ROWS = MAX_Y - MARGIN_TOP + 1; // 41 visible rows (2..42)

    reg [6:0] cursor_x = MARGIN_LEFT; // 0 to 79
    reg [5:0] cursor_y = MARGIN_TOP;  // 0 to 44
    reg [5:0] scroll_offset = 0;      // 0 to 40 circular row offset

    // Translate logical screen cursor_y (2..42) to physical RAM row using scroll_offset
    wire [5:0] cur_rel_y = cursor_y - MARGIN_TOP;
    wire [6:0] cur_scrolled = cur_rel_y + scroll_offset;
    wire [5:0] phys_cursor_y = MARGIN_TOP + ((cur_scrolled >= NUM_ROWS) ? (cur_scrolled - NUM_ROWS) : cur_scrolled[5:0]);

    reg clearing = 0;
    reg [11:0] clear_addr = 0;
    reg clearing_line = 0;
    reg [6:0] clear_x = 0;

    assign term_busy = clearing | clearing_line;

    wire [6:0] active_write_x = clearing_line ? clear_x : cursor_x;
    wire [11:0] write_addr = (phys_cursor_y << 6) + (phys_cursor_y << 4) + active_write_x;
    
    reg [2:0] skip_count = 0;
    reg [1:0] vdu_state = 0;
    reg [7:0] vdu_x = 0;
    reg [3:0] current_color_reg = 4'd7; // Default to white (7)

    // Handle incoming characters (clk_sys)
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            cursor_x <= MARGIN_LEFT;
            cursor_y <= MARGIN_TOP;
            scroll_offset <= 0;
            clearing <= 1; // Clear memory on reset
            clear_addr <= 0;
            clearing_line <= 0;
            clear_x <= 0;
            skip_count <= 0;
            vdu_state <= 0;
            current_color_reg <= 4'd7;
        end else if (clearing) begin
            // Write space with current color
            text_ram[clear_addr] <= {4'h0, current_color_reg, 8'h20}; 
            clear_addr <= clear_addr + 1;
            if (clear_addr == 4095) begin
                clearing <= 0;
            end
        end else if (clearing_line) begin
            // Clear the newly scrolled bottom line (80 columns)
            text_ram[write_addr] <= {4'h0, current_color_reg, 8'h20};
            if (clear_x == 7'd79) begin
                clearing_line <= 0;
                clear_x <= 0;
            end else begin
                clear_x <= clear_x + 1;
            end
        end else begin
            if (rx_valid) begin
                if (skip_count > 0) begin
                    skip_count <= skip_count - 1;
                end else if (vdu_state == 1) begin
                    vdu_x <= rx_data;
                    vdu_state <= 2;
                end else if (vdu_state == 2) begin
                    cursor_x <= (vdu_x < (80 - MARGIN_LEFT - MARGIN_RIGHT)) ? vdu_x + MARGIN_LEFT : MARGIN_LEFT;
                    cursor_y <= (rx_data < (45 - MARGIN_TOP - MARGIN_BOTTOM)) ? rx_data + MARGIN_TOP : MARGIN_TOP;
                    vdu_state <= 0;
                end else if (vdu_state == 3) begin
                    // VDU 17 color parameter
                    if (rx_data < 128) begin // Only foreground colors for now
                        current_color_reg <= rx_data[3:0];
                    end
                    vdu_state <= 0;
                end else if (rx_data == 8'h1F) begin // VDU 31 (TAB)
                    vdu_state <= 1;
                end else if (rx_data == 8'h11) begin // VDU 17 (COLOUR)
                    vdu_state <= 3;
                end else if (rx_data == 8'h19) begin // VDU 25 (PLOT)
                    skip_count <= 5;
                end else if (rx_data == 8'h12) begin // VDU 18 (GCOL)
                    skip_count <= 2;
                end else if (rx_data == 8'h16) begin // VDU 22 (MODE)
                    skip_count <= 1;
                end else if (rx_data == 8'h0C) begin // ASCII 12 Form Feed -> CLEAR SCREEN
                    clearing <= 1;
                    clear_addr <= 0;
                    clearing_line <= 0;
                    clear_x <= 0;
                    scroll_offset <= 0;
                    cursor_x <= MARGIN_LEFT;
                    cursor_y <= MARGIN_TOP;
                end else if (rx_data == 8'h0D) begin // CR (Carriage Return)
                    cursor_x <= MARGIN_LEFT;
                end else if (rx_data == 8'h0A) begin // LF (Line Feed)
                    if (cursor_y >= MAX_Y) begin
                        cursor_y <= MAX_Y;
                        scroll_offset <= (scroll_offset == (NUM_ROWS - 1)) ? 6'd0 : (scroll_offset + 6'd1);
                        clearing_line <= 1;
                        clear_x <= 0;
                    end else begin
                        cursor_y <= cursor_y + 1;
                    end
                end else if (rx_data == 8'h08) begin // Backspace
                    if (cursor_x > MARGIN_LEFT) cursor_x <= cursor_x - 1;
                end else begin
                    // Write to RAM
                    text_ram[write_addr] <= {4'h0, current_color_reg, rx_data};
                    
                    // Advance cursor
                    if (cursor_x >= MAX_X) begin
                        cursor_x <= MARGIN_LEFT;
                        if (cursor_y >= MAX_Y) begin
                            cursor_y <= MAX_Y;
                            scroll_offset <= (scroll_offset == (NUM_ROWS - 1)) ? 6'd0 : (scroll_offset + 6'd1);
                            clearing_line <= 1;
                            clear_x <= 0;
                        end else begin
                            cursor_y <= cursor_y + 1;
                        end
                    end else begin
                        cursor_x <= cursor_x + 1;
                    end
                end
            end
        end
    end

    // BBC BASIC logical colors
    function [23:0] get_color;
        input [3:0] c;
        begin
            case (c[2:0])
                3'd0: get_color = 24'h000000; // Black (will be transparent on overlay unless term_active logic changes)
                3'd1: get_color = 24'hFF0000; // Red
                3'd2: get_color = 24'h00FF00; // Green
                3'd3: get_color = 24'hFFFF00; // Yellow
                3'd4: get_color = 24'h0000FF; // Blue
                3'd5: get_color = 24'hFF00FF; // Magenta
                3'd6: get_color = 24'h00FFFF; // Cyan
                3'd7: get_color = 24'hFFFFFF; // White
            endcase
        end
    endfunction

    // Read logic for HDMI (clk_pixel)
    // cx is 0..1279, cy is 0..719
    // Character X, Y: cx / 16, cy / 16 (because 2x scaling of 8x8 font = 16x16)
    wire [6:0] char_x = cx[10:4];
    wire [5:0] char_y = cy[9:4];
    
    // Pixel within character (0..7)
    wire [2:0] pixel_x = cx[3:1]; 
    wire [2:0] pixel_y = cy[3:1]; 

    reg [5:0] scroll_offset_pix = 0;
    always @(posedge clk_pixel) begin
        scroll_offset_pix <= scroll_offset;
    end

    wire in_scroll_region = (char_y >= MARGIN_TOP) && (char_y <= MAX_Y);
    wire [5:0] read_rel_y = char_y - MARGIN_TOP;
    wire [6:0] read_scrolled = read_rel_y + scroll_offset_pix;
    wire [5:0] phys_read_y = in_scroll_region ?
        (MARGIN_TOP + ((read_scrolled >= NUM_ROWS) ? (read_scrolled - NUM_ROWS) : read_scrolled[5:0])) :
        char_y;
    
    wire [11:0] read_addr = (phys_read_y << 6) + (phys_read_y << 4) + char_x;
    
    reg [15:0] current_ram_data;
    reg [7:0] current_char;
    reg [3:0] current_char_color;
    reg [7:0] font_row;
    
    always @(posedge clk_pixel) begin
        // Cycle 1: read character and color from text buffer
        current_ram_data <= text_ram[read_addr];
        current_char <= text_ram[read_addr][7:0];
        current_char_color <= text_ram[read_addr][11:8];
        
        // Cycle 2: read font row based on character and pixel_y
        font_row <= font_rom[{current_char[6:0], pixel_y}];
    end
    
    // Delay coordinates and color to match 2-cycle RAM pipeline
    reg [6:0] char_x_d1, char_x_d2;
    reg [5:0] char_y_d1, char_y_d2;
    reg [2:0] pixel_x_d1, pixel_x_d2;
    reg [3:0] char_color_d1;
    
    always @(posedge clk_pixel) begin
        char_x_d1 <= char_x;
        char_x_d2 <= char_x_d1;
        char_y_d1 <= char_y;
        char_y_d2 <= char_y_d1;
        pixel_x_d1 <= pixel_x;
        pixel_x_d2 <= pixel_x_d1;
        
        char_color_d1 <= current_char_color; // Available after cycle 1
    end
    
    // Cycle 3: extract pixel using delayed pixel_x
    wire pixel_on = font_row[pixel_x_d2];
    
    wire is_cursor = (char_x_d2 == cursor_x) && (char_y_d2 == cursor_y);
    
    // Set active if pixel is on or it's the cursor.
    // If pixel is black (color 0), it won't be transparent anymore if we want black text.
    // Let's keep it transparent for black if the user likes that, or make it opaque black?
    // Actually, "pixel_on" means text. "is_cursor" means cursor.
    assign term_active = pixel_on | is_cursor;
    
    // Output color
    assign term_rgb = is_cursor ? 24'hFFFFFF : get_color(char_color_d1);
    
endmodule
