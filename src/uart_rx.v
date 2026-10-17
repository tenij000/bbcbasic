`timescale 1ns / 1ps

// Simple 8-N-1 UART Receiver
module uart_rx #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid
);

    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;
    localparam HALF_PERIOD = BIT_PERIOD / 2;

    reg [15:0] counter;
    reg [3:0]  bit_idx;
    reg [2:0]  state;
    
    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;

    // Sync RX to avoid metastability
    reg rx_sync1, rx_sync2;
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            counter <= 0;
            bit_idx <= 0;
            valid <= 0;
            data <= 0;
        end else begin
            valid <= 0; // Default: valid is a 1-cycle pulse
            
            case (state)
                IDLE: begin
                    if (rx_sync2 == 1'b0) begin
                        state <= START;
                        counter <= 0;
                    end
                end
                
                START: begin
                    if (counter == HALF_PERIOD) begin
                        if (rx_sync2 == 1'b0) begin
                            state <= DATA;
                            counter <= 0;
                            bit_idx <= 0;
                        end else begin
                            state <= IDLE; // False start
                        end
                    end else begin
                        counter <= counter + 1;
                    end
                end
                
                DATA: begin
                    if (counter == BIT_PERIOD) begin
                        counter <= 0;
                        data[bit_idx] <= rx_sync2;
                        if (bit_idx == 7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        counter <= counter + 1;
                    end
                end
                
                STOP: begin
                    if (counter == BIT_PERIOD) begin
                        valid <= 1; // Pulse valid
                        state <= IDLE;
                    end else begin
                        counter <= counter + 1;
                    end
                end
            endcase
        end
    end

endmodule
