module vdu_parser (
    input clk,
    input reset,
    input [7:0] din,
    input valid,
    
    // Outputs to GPU line drawer
    output reg signed [15:0] draw_x0,
    output reg signed [15:0] draw_y0,
    output reg signed [15:0] draw_x1,
    output reg signed [15:0] draw_y1,
    output reg [7:0]  draw_color,
    output reg        draw_start,
    output reg        draw_is_circle,
    output reg        draw_is_clear,
    input             draw_busy,
    
    // Hardware Sprite Outputs
    output reg [3:0]  sprite_id,
    output reg [11:0] sprite_x_out,
    output reg [11:0] sprite_y_out,
    output reg        sprite_active_out,
    output reg        sprite_pos_we,
    output reg        sprite_active_we,
    output reg [7:0]  sprite_waddr,
    output reg [7:0]  sprite_wdata,
    output reg        sprite_we,

    // Hardware PSG Sound Outputs (PLOT 210..213, Pitch, Vol_Env)
    output reg [1:0]  snd_ch,
    output reg [7:0]  snd_pitch,
    output reg [7:0]  snd_vol,
    output reg        snd_we
);

    reg [3:0] state;
    reg [7:0] k, xl, yl;
    
    reg signed [15:0] last_x;
    reg signed [15:0] last_y;
    reg [7:0]  current_gcol;
    
    always @(posedge clk) begin
        if (reset) begin
            state <= 0;
            draw_start <= 0;
            draw_is_circle <= 0;
            draw_is_clear <= 0;
            current_gcol <= 7; // white
            last_x <= 0;
            last_y <= 0;
            sprite_id <= 0;
            sprite_x_out <= 0;
            sprite_y_out <= 0;
            sprite_active_out <= 0;
            sprite_pos_we <= 0;
            sprite_active_we <= 0;
            sprite_waddr <= 0;
            sprite_wdata <= 0;
            sprite_we <= 0;
            snd_ch <= 0;
            snd_pitch <= 0;
            snd_vol <= 0;
            snd_we <= 0;
        end else begin
            // Clear start pulses
            sprite_we <= 0;
            sprite_pos_we <= 0;
            sprite_active_we <= 0;
            snd_we <= 0;
            
            if (draw_start && draw_busy) begin
                draw_start <= 0;
            end
            
            if (valid && !draw_start) begin
                case (state)
                    0: begin
                        if (din == 8'h19) state <= 1;      // VDU 25 (PLOT, 5 bytes)
                        else if (din == 8'h12) state <= 6; // VDU 18 (GCOL, 2 bytes)
                        else if (din == 8'h16) state <= 8; // VDU 22 (MODE, 1 byte)
                        else if (din == 8'h11) state <= 9; // VDU 17 (COLOUR, 1 byte)
                        else if (din == 8'h1F) state <= 10;// VDU 31 (TAB, 2 bytes)
                        else if (din == 8'h10) begin       // VDU 16 (CLG)
                            draw_start <= 1;
                            draw_is_clear <= 1;
                            draw_is_circle <= 0;
                            draw_color <= 0; // Clear to Black
                        end
                    end
                    // VDU 25 (PLOT)
                    1: begin k <= din; state <= 2; end
                    2: begin xl <= din; state <= 3; end
                    3: begin draw_x1 <= {din, xl}; state <= 4; end // 16-bit signed X
                    4: begin yl <= din; state <= 5; end
                    5: begin 
                        draw_y1 <= {din, yl}; // 16-bit signed Y
                        state <= 0;
                        if (k == 4) begin
                            // Move absolute
                            last_x <= draw_x1;
                            last_y <= {din, yl};
                        end else if (k == 0) begin
                            // Move relative
                            last_x <= last_x + draw_x1;
                            last_y <= last_y + {din, yl};
                        end else if (k == 69) begin
                            // Point absolute
                            draw_x0 <= draw_x1;
                            draw_y0 <= {din, yl};
                            draw_color <= current_gcol;
                            draw_start <= 1;
                            draw_is_circle <= 0;
                            draw_is_clear <= 0;
                            last_x <= draw_x1;
                            last_y <= {din, yl};
                        end else if (k == 65) begin
                            // Point relative
                            draw_x0 <= last_x + draw_x1;
                            draw_y0 <= last_y + {din, yl};
                            draw_x1 <= last_x + draw_x1;
                            draw_y1 <= last_y + {din, yl};
                            draw_color <= current_gcol;
                            draw_start <= 1;
                            draw_is_circle <= 0;
                            draw_is_clear <= 0;
                            last_x <= last_x + draw_x1;
                            last_y <= last_y + {din, yl};
                        end else if (k == 5) begin
                            // Draw absolute line
                            draw_x0 <= last_x;
                            draw_y0 <= last_y;
                            draw_color <= current_gcol;
                            draw_start <= 1;
                            draw_is_circle <= 0;
                            draw_is_clear <= 0;
                            last_x <= draw_x1;
                            last_y <= {din, yl};
                        end else if (k == 1) begin
                            // Draw relative line
                            draw_x0 <= last_x;
                            draw_y0 <= last_y;
                            draw_x1 <= last_x + draw_x1; // convert relative to absolute
                            draw_y1 <= last_y + {din, yl}; // convert relative to absolute
                            draw_color <= current_gcol;
                            draw_start <= 1;
                            draw_is_circle <= 0;
                            draw_is_clear <= 0;
                            last_x <= last_x + draw_x1;
                            last_y <= last_y + {din, yl};
                        end else if (k >= 144 && k <= 159) begin
                            // Draw circle (BBC Basic uses 145 or 153 for circles)
                            draw_x0 <= last_x;
                            draw_y0 <= last_y;
                            if ((k & 8) == 0) begin
                                draw_x1 <= last_x + draw_x1;
                                draw_y1 <= last_y + {din, yl};
                            end
                            draw_color <= current_gcol;
                            draw_start <= 1;
                            draw_is_circle <= 1;
                            draw_is_clear <= 0;
                        end else if (k == 199) begin // Custom hardware circle command: PLOT 199, R, 0 (moved from 200)
                            draw_x0 <= last_x;
                            draw_y0 <= last_y;
                            draw_x1 <= last_x + draw_x1; // Center X + Radius X
                            draw_y1 <= last_y;           // Center Y + 0
                            draw_color <= current_gcol;
                            draw_start <= 1;
                            draw_is_circle <= 1;
                            draw_is_clear <= 0;
                        end else if (k == 200) begin
                            // PLOT 200, ID, 0 : Select Active Sprite (0-15)
                            sprite_id <= draw_x1[3:0];
                            last_x <= draw_x1;
                            last_y <= {din, yl};
                        end else if (k == 201) begin
                            // Custom hardware sprite command: PLOT 201, X, Y
                            sprite_x_out <= draw_x1[11:0];
                            sprite_y_out <= {din, yl}[11:0];
                            sprite_active_out <= 1;
                            sprite_pos_we <= 1;
                            sprite_active_we <= 1;
                            last_x <= draw_x1;
                            last_y <= {din, yl};
                        end else if (k == 202) begin
                            // PLOT 202: Disable Sprite
                            sprite_active_out <= 0;
                            sprite_active_we <= 1;
                            last_x <= draw_x1;
                            last_y <= {din, yl};
                        end else if (k == 203) begin
                            // PLOT 203, Addr, Color : Upload pixel to sprite RAM
                            sprite_waddr <= draw_x1[7:0];
                            sprite_wdata <= {din, yl}[7:0];
                            sprite_we <= 1;
                        end else if (k >= 210 && k <= 213) begin
                            // PLOT 210..213, Pitch, Vol_Env : Hardware PSG Sound Channel 0..3
                            snd_ch    <= k - 8'd210;
                            snd_pitch <= draw_x1[7:0];
                            snd_vol   <= {din, yl}[7:0];
                            snd_we    <= 1;
                        end
                    end
                    // VDU 18 (GCOL)
                    6: begin state <= 7; end // ignore mode (m) for now
                    7: begin current_gcol <= din; state <= 0; end
                    // VDU 22 (MODE n): Clear graphics screen if n < 128; preserve graphics if n >= 128 (Shadow/Overlay Mode)
                    8: begin
                        state <= 0;
                        current_gcol <= 8'd7;
                        last_x <= 16'sd0;
                        last_y <= 16'sd0;
                        if (!din[7]) begin
                            draw_start <= 1'b1;
                            draw_is_clear <= 1'b1;
                            draw_is_circle <= 1'b0;
                            draw_color <= 8'd0;
                        end
                    end
                    // VDU 17 (COLOUR c): skip 1 byte in graphics parser
                    9: begin state <= 0; end
                    // VDU 31 (TAB x, y): skip 2 bytes in graphics parser
                    10: begin state <= 11; end
                    11: begin state <= 0; end
                    
                    default: state <= 0;
                endcase
            end
        end
    end
endmodule

