`timescale 1ns / 1ps

module sd_spi (
    input  wire       clk,       // 27 MHz system clock
    input  wire       reset,
    input  wire       start,     // Pulse high for 1 clk on write to $A010
    input  wire [7:0] tx_data,   // Byte to transmit
    output reg  [7:0] rx_data,   // Received byte
    output reg        busy,      // High while 8-bit transfer in progress
    input  wire       slow_mode, // 1 = ~210 kHz (init), 0 = 3.375 MHz (fast)
    output reg        sd_clk,    // Pin 83 (SDIO_CLK)
    output reg        sd_mosi,   // Pin 82 (SDIO_CMD)
    input  wire       sd_miso    // Pin 84 (SDIO_D0)
);

    reg [7:0] tx_shift = 8'hFF;
    reg [7:0] rx_shift = 8'hFF;
    reg [3:0] bit_cnt  = 0;
    reg [6:0] clk_cnt  = 0;

    wire [6:0] half_period = slow_mode ? 7'd63 : 7'd3;

    always @(posedge clk) begin
        if (reset) begin
            busy     <= 1'b0;
            sd_clk   <= 1'b0;
            sd_mosi  <= 1'b1;
            rx_data  <= 8'hFF;
            bit_cnt  <= 4'd0;
            clk_cnt  <= 7'd0;
        end else if (!busy) begin
            sd_clk <= 1'b0;
            if (start) begin
                busy     <= 1'b1;
                tx_shift <= tx_data;
                sd_mosi  <= tx_data[7];
                bit_cnt  <= 4'd0;
                clk_cnt  <= 7'd0;
            end
        end else begin
            if (clk_cnt == half_period) begin
                clk_cnt <= 7'd0;
                if (sd_clk == 1'b0) begin
                    // Rising edge of SD_CLK: sample MISO
                    sd_clk   <= 1'b1;
                    rx_shift <= {rx_shift[6:0], sd_miso};
                end else begin
                    // Falling edge of SD_CLK: shift MOSI or finish
                    sd_clk <= 1'b0;
                    if (bit_cnt == 4'd7) begin
                        busy    <= 1'b0;
                        rx_data <= rx_shift;
                        sd_mosi <= 1'b1;
                    end else begin
                        bit_cnt  <= bit_cnt + 1'b1;
                        sd_mosi  <= tx_shift[6];
                        tx_shift <= {tx_shift[6:0], 1'b1};
                    end
                end
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end
    end

endmodule
