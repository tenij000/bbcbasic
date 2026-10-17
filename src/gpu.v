module gpu (
    input clk,
    input reset,
    
    // Command Interface (from VDU parser)
    input signed [15:0] x0, // BBC BASIC coordinates (0-1279, signed for wrapping)
    input signed [15:0] y0, // BBC BASIC coordinates (0-1023, signed for wrapping)
    input signed [15:0] x1,
    input signed [15:0] y1,
    input [7:0]  color,
    input        start,
    input        is_circle,
    input        is_clear,
    output reg   busy,
    
    // Framebuffer Pixel Write Interface
    output reg [9:0]  fb_x,
    output reg [8:0]  fb_y,
    output reg [7:0]  fb_color,
    output reg        fb_write,
    input             fb_ack
);

    // Scaling
    wire signed [15:0] sx0_raw = x0 >>> 1;
    wire signed [15:0] sx1_raw = x1 >>> 1;
    
    // Y scaling: 359 - ((y * 360) / 1024)
    wire signed [25:0] mult0 = y0 * 360;
    wire signed [25:0] mult1 = y1 * 360;
    
    wire signed [15:0] sy0_raw = 359 - (mult0 >>> 10);
    wire signed [15:0] sy1_raw = 359 - (mult1 >>> 10);

    // Bresenham Registers
    reg signed [15:0] x, y;
    reg signed [15:0] dx, dy;
    reg signed [15:0] sx, sy;
    reg signed [15:0] err, e2;
    reg signed [15:0] target_x, target_y;
    
    // Circle Registers
    reg signed [15:0] cx, cy;
    reg [2:0] octant; // 0 to 7
    reg drawing_circle;
    reg signed [15:0] tx, ty;

    // Clear Registers
    reg [9:0] clear_x;
    reg [8:0] clear_y;

    reg [3:0] state;

    always @(posedge clk) begin
        if (reset) begin
            state <= 0;
            busy <= 0;
            fb_write <= 0;
            drawing_circle <= 0;
        end else begin
            case (state)
                0: begin
                    fb_write <= 0;
                    if (start) begin
                        busy <= 1;
                        fb_color <= color;
                        drawing_circle <= is_circle;
                        
                        if (is_clear) begin
                            clear_x <= 0;
                            clear_y <= 0;
                            state <= 9; // Clear loop
                        end else if (is_circle) begin
                            // Calculate radius (in scaled X pixels)
                            cx <= sx0_raw;
                            cy <= sy0_raw;
                            x <= 0;
                            // dx is radius
                            y <= (sx1_raw > sx0_raw) ? (sx1_raw - sx0_raw) : (sx0_raw - sx1_raw);
                            err <= 3 - (2 * ((sx1_raw > sx0_raw) ? (sx1_raw - sx0_raw) : (sx0_raw - sx1_raw)));
                            octant <= 0;
                            state <= 6; // Circle draw loop
                        end else begin
                            x <= sx0_raw;
                            y <= sy0_raw;
                            target_x <= sx1_raw;
                            target_y <= sy1_raw;
                            
                            dx <= (sx1_raw > sx0_raw) ? (sx1_raw - sx0_raw) : (sx0_raw - sx1_raw);
                            sx <= (sx1_raw > sx0_raw) ? 1 : -1;
                            
                            dy <= (sy1_raw > sy0_raw) ? (sy1_raw - sy0_raw) : (sy0_raw - sy1_raw);
                            sy <= (sy1_raw > sy0_raw) ? 1 : -1;
                            
                            state <= 1;
                        end
                    end
                end
                
                // --- LINE DRAWING ---
                1: begin
                    err <= dx - dy;
                    state <= 2;
                end
                
                2: begin
                    // Request pixel draw
                    fb_x <= x[9:0];
                    fb_y <= y[8:0];
                    fb_write <= (x >= 0 && x < 640 && y >= 0 && y < 360) ? 1 : 0;
                    state <= 3;
                end
                
                3: begin
                    if (fb_ack || !fb_write) begin
                        fb_write <= 0;
                        if (x == target_x && y == target_y) begin
                            busy <= 0;
                            state <= 0;
                        end else begin
                            e2 <= err << 1;
                            state <= 4;
                        end
                    end
                end
                
                4: begin
                    if (e2 > -dy) begin
                        err <= err - dy;
                        x <= x + sx;
                    end
                    state <= 5;
                end
                
                5: begin
                    if (e2 < dx) begin
                        err <= err + dx;
                        y <= y + sy;
                    end
                    state <= 2;
                end

                // --- CIRCLE DRAWING ---
                6: begin
                    if (x <= y) begin
                        // Check bounds manually using signed math before assigning to unsigned fb_x/fb_y
                        // We will just stay in state 6 and compute the 8 points, but we'll use a sub-state or just compute them directly into a signed temp.
                        // Wait, it's easier to just make a signed temporary wire or register for the target.
                        state <= 7;
                    end else begin
                        busy <= 0;
                        state <= 0;
                    end
                end
                
                7: begin
                    case (octant)
                        0: begin tx = cx + x; ty = cy + y; end
                        1: begin tx = cx - x; ty = cy + y; end
                        2: begin tx = cx + x; ty = cy - y; end
                        3: begin tx = cx - x; ty = cy - y; end
                        4: begin tx = cx + y; ty = cy + x; end
                        5: begin tx = cx - y; ty = cy + x; end
                        6: begin tx = cx + y; ty = cy - x; end
                        7: begin tx = cx - y; ty = cy - x; end
                    endcase
                    
                    fb_x <= tx[9:0];
                    fb_y <= ty[8:0];
                    fb_write <= (tx >= 0 && tx < 640 && ty >= 0 && ty < 360) ? 1 : 0;
                    
                    state <= 8;
                end
                
                8: begin
                    if (fb_ack || !fb_write) begin
                        fb_write <= 0;
                        if (octant == 7) begin
                            octant <= 0;
                            // Update algorithm state
                            if (err < 0) begin
                                err <= err + (x << 2) + 6;
                            end else begin
                                err <= err + ((x - y) << 2) + 10;
                                y <= y - 1;
                            end
                            x <= x + 1;
                            state <= 6;
                        end else begin
                            octant <= octant + 1;
                            state <= 6; // Next octant
                        end
                    end
                end
                
                // --- CLEAR SCREEN ---
                9: begin
                    fb_x <= clear_x;
                    fb_y <= clear_y;
                    fb_write <= 1;
                    state <= 10;
                end
                
                10: begin
                    if (fb_ack) begin
                        fb_write <= 0;
                        if (clear_x == 639) begin
                            clear_x <= 0;
                            if (clear_y == 359) begin
                                busy <= 0;
                                state <= 0;
                            end else begin
                                clear_y <= clear_y + 1;
                                state <= 9;
                            end
                        end else begin
                            clear_x <= clear_x + 1;
                            state <= 9;
                        end
                    end
                end

            endcase
        end
    end
endmodule
