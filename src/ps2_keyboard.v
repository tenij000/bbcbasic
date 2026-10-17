`timescale 1ns / 1ps

module ps2_keyboard (
    input  wire       clk,         // 27 MHz system clock
    input  wire       reset,
    input  wire       ps2_clk,     // Pin 74 (D+) - PS/2 Clock
    input  wire       ps2_data,    // Pin 73 (D-) - PS/2 Data
    output reg  [7:0] ascii_code,
    output reg        ascii_valid
);

    // --- 1. Synchronizer & Digital Debounce Filter ---
    reg [2:0] clk_sync  = 3'b111;
    reg [2:0] data_sync = 3'b111;
    always @(posedge clk) begin
        clk_sync  <= {clk_sync[1:0],  ps2_clk};
        data_sync <= {data_sync[1:0], ps2_data};
    end

    reg [7:0] clk_filter = 8'hFF;
    reg       ps2_clk_clean = 1'b1;
    reg       ps2_clk_prev  = 1'b1;

    always @(posedge clk) begin
        clk_filter <= {clk_filter[6:0], clk_sync[2]};
        ps2_clk_prev <= ps2_clk_clean;
        if (clk_filter == 8'hFF)
            ps2_clk_clean <= 1'b1;
        else if (clk_filter == 8'h00)
            ps2_clk_clean <= 1'b0;
    end

    wire ps2_clk_falling = (ps2_clk_prev == 1'b1) && (ps2_clk_clean == 1'b0);
    wire ps2_data_clean  = data_sync[2];

    // --- 2. 11-bit Frame Receiver + Timeout Watchdog ---
    reg [3:0]  bit_count = 0;
    reg [10:0] shift_reg = 0;
    reg [15:0] timeout_cnt = 0;
    reg [7:0]  scancode = 0;
    reg        scancode_ready = 0;

    always @(posedge clk) begin
        scancode_ready <= 0;
        if (reset) begin
            bit_count   <= 0;
            timeout_cnt <= 0;
        end else begin
            if (ps2_clk_falling) begin
                timeout_cnt <= 0;
                shift_reg   <= {ps2_data_clean, shift_reg[10:1]};
                if (bit_count == 4'd10) begin
                    bit_count <= 0;
                    // Check Start bit (0) and Stop bit (1)
                    if (shift_reg[1] == 1'b0 && ps2_data_clean == 1'b1) begin
                        scancode       <= shift_reg[9:2];
                        scancode_ready <= 1'b1;
                    end
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end else if (bit_count != 0) begin
                // Reset bit_count if bus idle for > 2.4ms (65535 cycles @ 27MHz)
                if (timeout_cnt == 16'hFFFF) begin
                    bit_count   <= 0;
                    timeout_cnt <= 0;
                end else begin
                    timeout_cnt <= timeout_cnt + 1'b1;
                end
            end
        end
    end

    // --- 3. PS/2 Set 2 Scancode Decoder & Modifier State ---
    reg is_break  = 1'b0;
    reg is_ext    = 1'b0;
    reg shift_l   = 1'b0;
    reg shift_r   = 1'b0;
    reg caps_lock = 1'b1; // Default ON for BBC BASIC uppercase keywords!

    wire shift = shift_l | shift_r;
    wire upper = caps_lock ^ shift;

    reg [7:0] decoded_char;

    always @(*) begin
        decoded_char = 8'h00;
        case (scancode)
            // Letters A - Z
            8'h1C: decoded_char = upper ? "A" : "a";
            8'h32: decoded_char = upper ? "B" : "b";
            8'h21: decoded_char = upper ? "C" : "c";
            8'h23: decoded_char = upper ? "D" : "d";
            8'h24: decoded_char = upper ? "E" : "e";
            8'h2B: decoded_char = upper ? "F" : "f";
            8'h34: decoded_char = upper ? "G" : "g";
            8'h33: decoded_char = upper ? "H" : "h";
            8'h43: decoded_char = upper ? "I" : "i";
            8'h3B: decoded_char = upper ? "J" : "j";
            8'h42: decoded_char = upper ? "K" : "k";
            8'h4B: decoded_char = upper ? "L" : "l";
            8'h3A: decoded_char = upper ? "M" : "m";
            8'h31: decoded_char = upper ? "N" : "n";
            8'h44: decoded_char = upper ? "O" : "o";
            8'h4D: decoded_char = upper ? "P" : "p";
            8'h15: decoded_char = upper ? "Q" : "q";
            8'h2D: decoded_char = upper ? "R" : "r";
            8'h1B: decoded_char = upper ? "S" : "s";
            8'h2C: decoded_char = upper ? "T" : "t";
            8'h3C: decoded_char = upper ? "U" : "u";
            8'h2A: decoded_char = upper ? "V" : "v";
            8'h1D: decoded_char = upper ? "W" : "w";
            8'h22: decoded_char = upper ? "X" : "x";
            8'h35: decoded_char = upper ? "Y" : "y";
            8'h1A: decoded_char = upper ? "Z" : "z";

            // Top row numbers & symbols (US layout)
            8'h16: decoded_char = shift ? "!" : "1";
            8'h1E: decoded_char = shift ? "@" : "2";
            8'h26: decoded_char = shift ? "#" : "3";
            8'h25: decoded_char = shift ? "$" : "4";
            8'h2E: decoded_char = shift ? "%" : "5";
            8'h36: decoded_char = shift ? "^" : "6";
            8'h3D: decoded_char = shift ? "&" : "7";
            8'h3E: decoded_char = shift ? "*" : "8";
            8'h46: decoded_char = shift ? "(" : "9";
            8'h45: decoded_char = shift ? ")" : "0";

            // Numpad numbers & operators
            8'h70: decoded_char = "0";
            8'h69: decoded_char = "1";
            8'h72: decoded_char = "2";
            8'h7A: decoded_char = "3";
            8'h6B: decoded_char = "4";
            8'h73: decoded_char = "5";
            8'h74: decoded_char = "6";
            8'h6C: decoded_char = "7";
            8'h75: decoded_char = "8";
            8'h7D: decoded_char = "9";
            8'h71: decoded_char = ".";
            8'h79: decoded_char = "+";
            8'h7B: decoded_char = "-";
            8'h7C: decoded_char = "*";

            // Punctuation & Special Keys
            8'h29: decoded_char = " ";                  // Space
            8'h5A: decoded_char = 8'h0D;                // Enter -> CR
            8'h66: decoded_char = 8'h08;                // Backspace -> BS
            8'h76: decoded_char = 8'h1B;                // Escape -> ESC
            8'h4E: decoded_char = shift ? "_" : "-";
            8'h55: decoded_char = shift ? "+" : "=";
            8'h54: decoded_char = shift ? "{" : "[";
            8'h5B: decoded_char = shift ? "}" : "]";
            8'h5D: decoded_char = shift ? "|" : "\\";
            8'h4C: decoded_char = shift ? ":" : ";";
            8'h52: decoded_char = shift ? "\"" : "'";
            8'h41: decoded_char = shift ? "<" : ",";
            8'h49: decoded_char = shift ? ">" : ".";
            8'h4A: decoded_char = is_ext ? "/" : (shift ? "?" : "/");
            8'h0E: decoded_char = shift ? "~" : "`";
            default: decoded_char = 8'h00;
        endcase
    end

    always @(posedge clk) begin
        ascii_valid <= 1'b0;
        if (reset) begin
            is_break  <= 1'b0;
            is_ext    <= 1'b0;
            shift_l   <= 1'b0;
            shift_r   <= 1'b0;
            caps_lock <= 1'b1; // Start met Caps Lock aan voor BBC BASIC
        end else if (scancode_ready) begin
            if (scancode == 8'hF0) begin
                is_break <= 1'b1;
            end else if (scancode == 8'hE0) begin
                is_ext <= 1'b1;
            end else begin
                if (is_break) begin
                    // Key released
                    is_break <= 1'b0;
                    is_ext   <= 1'b0;
                    if (scancode == 8'h12) shift_l <= 1'b0;
                    if (scancode == 8'h59) shift_r <= 1'b0;
                end else begin
                    // Key pressed
                    is_ext <= 1'b0;
                    if (scancode == 8'h12) begin
                        shift_l <= 1'b1;
                    end else if (scancode == 8'h59) begin
                        shift_r <= 1'b1;
                    end else if (scancode == 8'h58) begin
                        caps_lock <= ~caps_lock;
                    end else if (decoded_char != 8'h00) begin
                        ascii_code  <= decoded_char;
                        ascii_valid <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
