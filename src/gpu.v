module gpu (
    input clk,
    input reset,
    
    // Command Interface (from VDU parser)
    input signed [15:0] x0, // BBC BASIC coordinates (0-1279, signed for wrapping)
    input signed [15:0] y0, // BBC BASIC coordinates (0-1023, signed for wrapping)
    input signed [15:0] x1,
    input signed [15:0] y1,
    input signed [15:0] x2,
    input signed [15:0] y2,
    input [7:0]  color,
    input        start,
    input        is_circle,
    input        is_clear,
    input        is_fill,
    input        is_triangle,
    output reg   busy,
    
    // Framebuffer Pixel Write Interface
    output reg [9:0]  fb_x,
    output reg [8:0]  fb_y,
    output reg [7:0]  fb_color,
    output reg        fb_write,
    input             fb_ack
);

    // Scaling (1280x1024 BBC BASIC -> 640x360 SDRAM Framebuffer)
    wire signed [15:0] sx0_raw = x0 >>> 1;
    wire signed [15:0] sx1_raw = x1 >>> 1;
    wire signed [15:0] sx2_raw = x2 >>> 1;
    
    // Y scaling: 359 - ((y * 360) / 1024)
    wire signed [25:0] mult0 = y0 * 360;
    wire signed [25:0] mult1 = y1 * 360;
    wire signed [25:0] mult2 = y2 * 360;
    
    wire signed [15:0] sy0_raw = 359 - (mult0 >>> 10);
    wire signed [15:0] sy1_raw = 359 - (mult1 >>> 10);
    wire signed [15:0] sy2_raw = 359 - (mult2 >>> 10);

    // Clamped Solid Rectangle Bounds (0..639, 0..359)
    wire signed [15:0] min_rx = (sx0_raw < sx1_raw) ? sx0_raw : sx1_raw;
    wire signed [15:0] max_rx = (sx0_raw > sx1_raw) ? sx0_raw : sx1_raw;
    wire signed [15:0] min_ry = (sy0_raw < sy1_raw) ? sy0_raw : sy1_raw;
    wire signed [15:0] max_ry = (sy0_raw > sy1_raw) ? sy0_raw : sy1_raw;

    wire [9:0] rx0 = (min_rx < 0) ? 10'd0 : (min_rx > 639) ? 10'd639 : min_rx[9:0];
    wire [9:0] rx1 = (max_rx < 0) ? 10'd0 : (max_rx > 639) ? 10'd639 : max_rx[9:0];
    wire [8:0] ry0 = (min_ry < 0) ? 9'd0  : (min_ry > 359) ? 9'd359  : min_ry[8:0];
    wire [8:0] ry1 = (max_ry < 0) ? 9'd0  : (max_ry > 359) ? 9'd359  : max_ry[8:0];

    // Bresenham Line & Ray Registers
    reg signed [15:0] x, y;
    reg signed [15:0] dx, dy;
    reg signed [15:0] sx, sy;
    reg signed [15:0] err, e2;
    reg signed [15:0] target_x, target_y;
    
    // Circle Registers
    reg signed [15:0] cx, cy;
    reg [2:0] octant; // 0 to 7
    reg drawing_circle;
    reg drawing_fill;
    reg drawing_triangle;
    reg signed [15:0] tx, ty;

    // Triangle Outer 4-Connected Edge Walk Registers
    reg signed [15:0] tri_x0, tri_y0;
    reg signed [15:0] edge_x, edge_y;
    reg signed [15:0] edge_tx, edge_ty;
    reg signed [15:0] edge_dx, edge_dy;
    reg signed [15:0] edge_sx, edge_sy;
    reg signed [15:0] edge_err;
    wire signed [15:0] ee2 = edge_err <<< 1;

    // Solid Rectangle / Clear Screen Registers
    reg [9:0] clear_x, rect_x0, rect_x1;
    reg [8:0] clear_y, rect_y1;

    reg [3:0] state;

    always @(posedge clk) begin
        if (reset) begin
            state <= 0;
            busy <= 0;
            fb_write <= 0;
            drawing_circle <= 0;
            drawing_fill <= 0;
            drawing_triangle <= 0;
        end else begin
            case (state)
                0: begin
                    fb_write <= 0;
                    if (start) begin
                        busy <= 1;
                        fb_color <= color;
                        drawing_circle <= is_circle;
                        drawing_fill <= is_fill;
                        drawing_triangle <= is_triangle;
                        
                        if (is_clear) begin
                            rect_x0 <= 10'd0;
                            clear_x <= 10'd0;
                            clear_y <= 9'd0;
                            rect_x1 <= 10'd639;
                            rect_y1 <= 9'd359;
                            state <= 9; // Fast SDRAM Rect/Clear loop
                        end else if (is_fill && !is_circle && !is_triangle) begin
                            // Solid Filled Rectangle (PLOT 101 / PLOT 97 / RECT X,Y,W,H,1)
                            rect_x0 <= rx0;
                            clear_x <= rx0;
                            clear_y <= ry0;
                            rect_x1 <= rx1;
                            rect_y1 <= ry1;
                            state <= 9;
                        end else if (is_circle) begin
                            // Outline or Filled Circle (radius in scaled X pixels)
                            cx <= sx0_raw;
                            cy <= sy0_raw;
                            x <= 0;
                            y <= (sx1_raw > sx0_raw) ? (sx1_raw - sx0_raw) : (sx0_raw - sx1_raw);
                            err <= 3 - (2 * ((sx1_raw > sx0_raw) ? (sx1_raw - sx0_raw) : (sx0_raw - sx1_raw)));
                            octant <= 0;
                            state <= 6; // Circle draw loop
                        end else begin
                            if (is_triangle) begin
                                tri_x0   <= sx0_raw;
                                tri_y0   <= sy0_raw;
                                edge_x   <= sx1_raw;
                                edge_y   <= sy1_raw;
                                edge_tx  <= sx2_raw;
                                edge_ty  <= sy2_raw;
                                edge_dx  <= (sx2_raw > sx1_raw) ? (sx2_raw - sx1_raw) : (sx1_raw - sx2_raw);
                                edge_sx  <= (sx2_raw > sx1_raw) ? 16'sd1 : -16'sd1;
                                edge_dy  <= (sy2_raw > sy1_raw) ? (sy2_raw - sy1_raw) : (sy1_raw - sy2_raw);
                                edge_sy  <= (sy2_raw > sy1_raw) ? 16'sd1 : -16'sd1;
                                edge_err <= ((sx2_raw > sx1_raw) ? (sx2_raw - sx1_raw) : (sx1_raw - sx2_raw)) -
                                            ((sy2_raw > sy1_raw) ? (sy2_raw - sy1_raw) : (sy1_raw - sy2_raw));
                            end
                            x <= sx0_raw;
                            y <= sy0_raw;
                            target_x <= sx1_raw;
                            target_y <= sy1_raw;
                            
                            dx <= (sx1_raw > sx0_raw) ? (sx1_raw - sx0_raw) : (sx0_raw - sx1_raw);
                            sx <= (sx1_raw > sx0_raw) ? 16'sd1 : -16'sd1;
                            
                            dy <= (sy1_raw > sy0_raw) ? (sy1_raw - sy0_raw) : (sy0_raw - sy1_raw);
                            sy <= (sy1_raw > sy0_raw) ? 16'sd1 : -16'sd1;
                            
                            state <= 1;
                        end
                    end
                end
                
                // --- LINE & TRIANGLE RAY DRAWING ---
                1: begin
                    err <= dx - dy;
                    state <= 2;
                end
                
                2: begin
                    fb_x <= x[9:0];
                    fb_y <= y[8:0];
                    fb_write <= (x >= 0 && x < 640 && y >= 0 && y < 360) ? 1'b1 : 1'b0;
                    state <= 3;
                end
                
                3: begin
                    if (fb_ack || !fb_write) begin
                        fb_write <= 0;
                        if (x == target_x && y == target_y) begin
                            if (drawing_triangle) begin
                                if (edge_x == edge_tx && edge_y == edge_ty) begin
                                    drawing_triangle <= 0;
                                    busy <= 0;
                                    state <= 0;
                                end else begin
                                    state <= 11; // Advance outer triangle edge by 1 Manhattan step
                                end
                            end else begin
                                busy <= 0;
                                state <= 0;
                            end
                        end else begin
                            e2 <= err <<< 1;
                            state <= 4;
                        end
                    end
                end
                
                4: begin
                    if (drawing_triangle) begin
                        // 4-connected ray step guarantees 100% gap-free solid triangles
                        if (e2 > -dy) begin
                            err <= err - dy;
                            x <= x + sx;
                        end else if (e2 < dx) begin
                            err <= err + dx;
                            y <= y + sy;
                        end
                        state <= 2;
                    end else begin
                        if (e2 > -dy) begin
                            err <= err - dy;
                            x <= x + sx;
                        end
                        state <= 5;
                    end
                end
                
                5: begin
                    if (e2 < dx) begin
                        err <= err + dx;
                        y <= y + sy;
                    end
                    state <= 2;
                end

                // --- CIRCLE & SOLID DISC DRAWING ---
                6: begin
                    if (x <= y) begin
                        if (drawing_fill) begin
                            tx <= cx - (octant[2] ? y : x);
                            target_x <= cx + (octant[2] ? y : x);
                            case (octant[2:1])
                                2'd0: ty <= cy + y;
                                2'd1: ty <= cy - y;
                                2'd2: ty <= cy + x;
                                2'd3: ty <= cy - x;
                            endcase
                        end else begin
                            case (octant)
                                3'd0: begin tx <= cx + x; ty <= cy + y; end
                                3'd1: begin tx <= cx - x; ty <= cy + y; end
                                3'd2: begin tx <= cx + x; ty <= cy - y; end
                                3'd3: begin tx <= cx - x; ty <= cy - y; end
                                3'd4: begin tx <= cx + y; ty <= cy + x; end
                                3'd5: begin tx <= cx - y; ty <= cy + x; end
                                3'd6: begin tx <= cx + y; ty <= cy - x; end
                                3'd7: begin tx <= cx - y; ty <= cy - x; end
                            endcase
                        end
                        state <= 7;
                    end else begin
                        busy <= 0;
                        state <= 0;
                    end
                end
                
                7: begin
                    fb_x <= tx[9:0];
                    fb_y <= ty[8:0];
                    fb_write <= (tx >= 0 && tx < 640 && ty >= 0 && ty < 360) ? 1'b1 : 1'b0;
                    state <= 8;
                end
                
                8: begin
                    if (fb_ack || !fb_write) begin
                        fb_write <= 0;
                        if (drawing_fill && (tx < target_x)) begin
                            tx <= tx + 16'sd1;
                            state <= 7;
                        end else if ((drawing_fill && octant == 3'd6) || (!drawing_fill && octant == 3'd7)) begin
                            octant <= 3'd0;
                            if (err < 0) begin
                                err <= err + (x << 2) + 16'sd6;
                            end else begin
                                err <= err + ((x - y) << 2) + 16'sd10;
                                y <= y - 16'sd1;
                            end
                            x <= x + 16'sd1;
                            state <= 6;
                        end else begin
                            octant <= drawing_fill ? (octant + 3'd2) : (octant + 3'd1);
                            state <= 6;
                        end
                    end
                end
                
                // --- SOLID RECTANGLE FILL & CLEAR SCREEN ---
                9: begin
                    fb_x <= clear_x;
                    fb_y <= clear_y;
                    fb_write <= 1'b1;
                    state <= 10;
                end
                
                10: begin
                    if (fb_ack) begin
                        fb_write <= 0;
                        if (clear_x >= rect_x1) begin
                            clear_x <= rect_x0;
                            if (clear_y >= rect_y1) begin
                                busy <= 0;
                                state <= 0;
                            end else begin
                                clear_y <= clear_y + 9'd1;
                                state <= 9;
                            end
                        end else begin
                            clear_x <= clear_x + 10'd1;
                            state <= 9;
                        end
                    end
                end

                // --- TRIANGLE OUTER EDGE 4-CONNECTED STEP ---
                11: begin
                    if (ee2 > -edge_dy) begin
                        edge_err <= edge_err - edge_dy;
                        edge_x   <= edge_x + edge_sx;
                    end else if (ee2 < edge_dx) begin
                        edge_err <= edge_err + edge_dx;
                        edge_y   <= edge_y + edge_sy;
                    end
                    state <= 12;
                end

                12: begin
                    x        <= tri_x0;
                    y        <= tri_y0;
                    target_x <= edge_x;
                    target_y <= edge_y;
                    dx       <= (edge_x > tri_x0) ? (edge_x - tri_x0) : (tri_x0 - edge_x);
                    sx       <= (edge_x > tri_x0) ? 16'sd1 : -16'sd1;
                    dy       <= (edge_y > tri_y0) ? (edge_y - tri_y0) : (tri_y0 - edge_y);
                    sy       <= (edge_y > tri_y0) ? 16'sd1 : -16'sd1;
                    state    <= 1;
                end

                default: state <= 0;
            endcase
        end
    end
endmodule
