module uart_tx #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD_RATE = 115200
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output wire       tx_busy
);

    localparam CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg [3:0] bit_idx;
    reg [15:0] clock_count;
    reg [9:0] shift_reg;
    reg active;

    assign tx_busy = active;

    always @(posedge clk) begin
        if (reset) begin
            tx <= 1'b1;
            active <= 1'b0;
            bit_idx <= 0;
            clock_count <= 0;
        end else begin
            if (active) begin
                if (clock_count < CLOCKS_PER_BIT - 1) begin
                    clock_count <= clock_count + 1;
                end else begin
                    clock_count <= 0;
                    tx <= shift_reg[0];
                    shift_reg <= {1'b1, shift_reg[9:1]};
                    if (bit_idx < 9) begin
                        bit_idx <= bit_idx + 1;
                    end else begin
                        active <= 0;
                    end
                end
            end else begin
                tx <= 1'b1;
                if (tx_start) begin
                    active <= 1'b1;
                    shift_reg <= {1'b1, tx_data, 1'b0}; // Stop bit, Data, Start bit
                    bit_idx <= 0;
                    clock_count <= 0;
                end
            end
        end
    end

endmodule
