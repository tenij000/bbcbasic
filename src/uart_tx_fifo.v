module uart_tx_fifo #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD_RATE = 115200,
    parameter FIFO_DEPTH = 4096
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx
);

    // FIFO Memory
    reg [7:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [11:0] write_ptr;
    reg [11:0] read_ptr;
    
    wire empty = (write_ptr == read_ptr);
    
    // UART TX State Machine
    localparam CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    reg [3:0] bit_idx;
    reg [15:0] clock_count;
    reg [9:0] shift_reg;
    reg active;

    always @(posedge clk) begin
        if (reset) begin
            write_ptr <= 0;
            read_ptr <= 0;
            tx <= 1'b1;
            active <= 0;
            bit_idx <= 0;
            clock_count <= 0;
        end else begin
            // Write to FIFO
            if (tx_start) begin
                fifo_mem[write_ptr] <= tx_data;
                write_ptr <= write_ptr + 1; // Wraps automatically at 4095
            end
            
            // Read from FIFO and Transmit
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
                if (!empty) begin
                    active <= 1'b1;
                    shift_reg <= {1'b1, fifo_mem[read_ptr], 1'b0}; // Stop bit, Data, Start bit
                    read_ptr <= read_ptr + 1;
                    bit_idx <= 0;
                    clock_count <= 0;
                end
            end
        end
    end

endmodule
