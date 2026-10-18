`timescale 1ns / 1ps

module sdram_framebuffer (
    input  wire        clk,        // 74.25 MHz pixel clock
    input  wire        rst_n,

    // UART write interface
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,

    // HDMI read interface
    input  wire [10:0] cx,         // current X
    input  wire [9:0]  cy,         // current Y
    output wire [23:0] rgb,        // output color

    // GPU Interface
    input  wire [9:0]  gpu_x,
    input  wire [8:0]  gpu_y,
    input  wire [7:0]  gpu_color,
    input  wire [2:0]  gpu_gcol_mode,
    input  wire        gpu_write,
    output reg         gpu_ack = 0,
    output reg  [7:0]  gpu_read_pixel = 0,

    // 6502 CPU SDRAM-Disk Interface (Upper 4 MB of SDRAM: addr[20] == 1)
    input  wire        rd_req_toggle,
    input  wire        rd_req_we,
    input  wire [21:0] rd_req_addr,
    input  wire [7:0]  rd_req_wdata,
    output reg  [7:0]  rd_rdata = 0,
    output reg         rd_ack_toggle = 0,

    // SDRAM Physical Pins
    output wire        O_sdram_clk,
    output wire        O_sdram_cke,
    output wire        O_sdram_cs_n,
    output wire        O_sdram_cas_n,
    output wire        O_sdram_ras_n,
    output wire        O_sdram_wen_n,
    inout  wire [31:0] IO_sdram_dq,
    output wire [10:0] O_sdram_addr,
    output wire [1:0]  O_sdram_ba,
    output wire [3:0]  O_sdram_dqm
);

    // ==========================================
    // UART Writer State Machine
    // ==========================================
    reg [9:0] write_x = 0;
    reg [8:0] write_y = 0;
    reg       uart_write_req = 0;
    reg [20:0] uart_word_addr = 0;
    reg [31:0] uart_din = 0;
    reg [3:0]  uart_wstrb = 0;
    wire      uart_write_ack;

    reg [2:0] rx_valid_sync = 0;
    wire rx_valid_pulse = rx_valid_sync[1] && !rx_valid_sync[2];

    always @(posedge clk) begin
        if (!rst_n) begin
            write_x <= 0;
            write_y <= 0;
            uart_write_req <= 0;
            rx_valid_sync <= 0;
        end else begin
            rx_valid_sync <= {rx_valid_sync[1:0], rx_valid};
            
            if (uart_write_ack) uart_write_req <= 0;

            if (rx_valid_pulse) begin
                uart_word_addr <= (write_y * 160) + write_x[9:2];
                
                case (write_x[1:0])
                    2'b00: begin uart_wstrb <= 4'b0001; uart_din <= {24'd0, rx_data}; end
                    2'b01: begin uart_wstrb <= 4'b0010; uart_din <= {16'd0, rx_data, 8'd0}; end
                    2'b10: begin uart_wstrb <= 4'b0100; uart_din <= {8'd0, rx_data, 16'd0}; end
                    2'b11: begin uart_wstrb <= 4'b1000; uart_din <= {rx_data, 24'd0}; end
                endcase
                
                uart_write_req <= 1;

                if (write_x == 639) begin
                    write_x <= 0;
                    if (write_y == 359) write_y <= 0;
                    else write_y <= write_y + 1;
                end else begin
                    write_x <= write_x + 1;
                end
            end
        end
    end

    // ==========================================
    // Line Fetcher State Machine
    // ==========================================
    reg [1:0] lb_fetch_state = 0;
    reg [7:0] lb_fetch_col = 0;
    reg [8:0] lb_fetch_y = 0;
    
    reg       lb_read_req = 0;
    wire      lb_read_ack;
    
    wire      lb_we;       // from arbiter
    wire [31:0] lb_wdata;  // from arbiter

    always @(posedge clk) begin
        if (!rst_n) begin
            lb_fetch_state <= 0;
            lb_read_req <= 0;
        end else begin
            case (lb_fetch_state)
                0: begin
                    if (cx == 1280 && cy[0] == 1) begin
                        lb_fetch_y <= (cy == 749) ? 9'd0 : ((cy + 1) >> 1);
                        if (((cy + 1) >> 1) < 360 || cy == 749) begin
                            lb_fetch_col <= 0;
                            lb_fetch_state <= 1;
                        end
                    end
                end
                1: begin
                    lb_read_req <= 1;
                    lb_fetch_state <= 2;
                end
                2: begin
                    if (lb_read_ack) begin
                        lb_read_req <= 0;
                        lb_fetch_state <= 3;
                    end
                end
                3: begin
                    if (lb_we) begin
                        if (lb_fetch_col == 159) begin
                            lb_fetch_state <= 0; // done
                        end else begin
                            lb_fetch_col <= lb_fetch_col + 1;
                            lb_fetch_state <= 1; // next
                        end
                    end
                end
            endcase
        end
    end

    // ==========================================
    // BRAM Line Buffer (Ping-Pong)
    // ==========================================
    reg [31:0] line_buffer [0:511];
    wire [8:0] lb_waddr = {lb_fetch_y[0], lb_fetch_col};

    always @(posedge clk) begin
        if (lb_we) begin
            line_buffer[lb_waddr] <= lb_wdata;
        end
    end

    // Output pixels
    wire [9:0] fb_x = cx[10:1];
    wire [8:0] fb_y = cy[9:1];

    wire [31:0] lb_rword = line_buffer[ {fb_y[0], fb_x[9:2]} ];
    reg [7:0]   lb_rbyte;
    
    always @(*) begin
        case (fb_x[1:0])
            2'b00: lb_rbyte = lb_rword[7:0];
            2'b01: lb_rbyte = lb_rword[15:8];
            2'b10: lb_rbyte = lb_rword[23:16];
            2'b11: lb_rbyte = lb_rword[31:24];
        endcase
    end

    // Convert 8-bit RGB332 to 24-bit RGB888
    wire [2:0] r3 = lb_rbyte[7:5];
    wire [2:0] g3 = lb_rbyte[4:2];
    wire [1:0] b2 = lb_rbyte[1:0];

    wire [7:0] r8 = {r3, r3, r3[2:1]};
    wire [7:0] g8 = {g3, g3, g3[2:1]};
    wire [7:0] b8 = {b2, b2, b2, b2};

    // Active display region check
    wire active = (cx < 1280 && cy < 720);
    assign rgb = active ? {r8, g8, b8} : 24'd0;

    // ==========================================
    // SDRAM Arbiter
    // ==========================================
    wire sdram_busy;
    wire sdram_data_ready;
    wire [31:0] sdram_dout;

    reg sdram_rd = 0;
    reg sdram_wr = 0;
    reg sdram_refresh = 0;
    reg [20:0] sdram_addr = 0;
    reg [31:0] sdram_din = 0;
    reg [3:0]  sdram_wstrb = 0;

    reg [9:0] refresh_counter = 0;
    reg refresh_req = 0;
    always @(posedge clk) begin
        if (!rst_n) begin
            refresh_counter <= 0;
            refresh_req <= 0;
        end else begin
            refresh_counter <= refresh_counter + 1;
            if (refresh_counter == 1023) begin
                refresh_req <= 1;
            end
            if (arb_state == ARB_REFRESH && !sdram_busy) begin
                refresh_req <= 0;
            end
        end
    end

    localparam ARB_IDLE      = 4'd0;
    localparam ARB_WAIT_BUSY = 4'd1;
    localparam ARB_REFRESH   = 4'd2;
    localparam ARB_WRITE     = 4'd3;
    localparam ARB_READ      = 4'd4;
    localparam ARB_WRITE_GPU = 4'd5;
    localparam ARB_WRITE_CPU = 4'd6;
    localparam ARB_READ_CPU  = 4'd7;
    localparam ARB_RMW_GPU   = 4'd8;
    localparam ARB_RMW_WRITE = 4'd9;
    reg [3:0] arb_state = 0;
    reg [3:0] arb_next_state = 0;

    reg [2:0] rd_req_sync = 0;
    reg [1:0] rd_byte_sel = 0;

    reg lb_read_ack_reg = 0;
    reg lb_we_reg = 0;
    reg [31:0] lb_wdata_reg = 0;
    reg uart_write_ack_reg = 0;

    assign lb_read_ack = lb_read_ack_reg;
    assign lb_we = lb_we_reg;
    assign lb_wdata = lb_wdata_reg;
    assign uart_write_ack = uart_write_ack_reg;

    reg [7:0] gpu_rgb332;
    always @(*) begin
        if (gpu_color[7:3] != 5'd0) begin
            gpu_rgb332 = gpu_color; // Direct 8-bit RGB332 palette (8..255)
        end else begin
            case (gpu_color[2:0])
                3'd0: gpu_rgb332 = 8'h00; // Black
                3'd1: gpu_rgb332 = 8'hE0; // Red
                3'd2: gpu_rgb332 = 8'h1C; // Green
                3'd3: gpu_rgb332 = 8'hFC; // Yellow
                3'd4: gpu_rgb332 = 8'h03; // Blue
                3'd5: gpu_rgb332 = 8'hE3; // Magenta
                3'd6: gpu_rgb332 = 8'h1F; // Cyan
                3'd7: gpu_rgb332 = 8'hFF; // White
            endcase
        end
    end
    
    wire [20:0] gpu_word_addr = (gpu_y * 160) + gpu_x[9:2];
    reg  [20:0] rmw_word_addr = 0;
    reg  [1:0]  rmw_byte_sel  = 0;

    reg [7:0] old_px;
    reg [7:0] rmw_px;
    reg [7:0] mapped_read_px;
    always @(*) begin
        case (rmw_byte_sel)
            2'b00: old_px = sdram_dout[7:0];
            2'b01: old_px = sdram_dout[15:8];
            2'b10: old_px = sdram_dout[23:16];
            2'b11: old_px = sdram_dout[31:24];
        endcase
        case (gpu_gcol_mode)
            3'd1:    rmw_px = old_px | gpu_rgb332; // GCOL 1: OR
            3'd2:    rmw_px = old_px & gpu_rgb332; // GCOL 2: AND
            3'd3:    rmw_px = old_px ^ gpu_rgb332; // GCOL 3: XOR
            default: rmw_px = ~old_px;             // GCOL 4: INVERT
        endcase
        case (old_px)
            8'h00:   mapped_read_px = 8'd0;
            8'hE0:   mapped_read_px = 8'd1;
            8'h1C:   mapped_read_px = 8'd2;
            8'hFC:   mapped_read_px = 8'd3;
            8'h03:   mapped_read_px = 8'd4;
            8'hE3:   mapped_read_px = 8'd5;
            8'h1F:   mapped_read_px = 8'd6;
            8'hFF:   mapped_read_px = 8'd7;
            default: mapped_read_px = old_px;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            arb_state <= ARB_IDLE;
            sdram_rd <= 0;
            sdram_wr <= 0;
            sdram_refresh <= 0;
            gpu_ack <= 0;
            gpu_read_pixel <= 0;
            rd_req_sync <= 0;
            rd_ack_toggle <= 0;
            rd_rdata <= 0;
        end else begin
            rd_req_sync <= {rd_req_sync[1:0], rd_req_toggle};
            lb_read_ack_reg <= 0;
            lb_we_reg <= 0;
            uart_write_ack_reg <= 0;
            gpu_ack <= 0;
            sdram_rd <= 0;
            sdram_wr <= 0;
            sdram_refresh <= 0;

            case (arb_state)
                ARB_IDLE: begin
                    if (refresh_req) begin
                        sdram_refresh <= 1;
                        arb_next_state <= ARB_REFRESH;
                        arb_state <= ARB_WAIT_BUSY;
                    end else if (uart_write_req) begin
                        sdram_addr <= uart_word_addr;
                        sdram_din <= uart_din;
                        sdram_wstrb <= uart_wstrb;
                        sdram_wr <= 1;
                        arb_next_state <= ARB_WRITE;
                        arb_state <= ARB_WAIT_BUSY;
                    end else if (gpu_write && !gpu_ack) begin
                        rmw_word_addr <= gpu_word_addr;
                        rmw_byte_sel  <= gpu_x[1:0];
                        if (gpu_gcol_mode == 3'd0) begin
                            sdram_addr <= gpu_word_addr;
                            case (gpu_x[1:0])
                                2'b00: begin sdram_wstrb <= 4'b0001; sdram_din <= {24'd0, gpu_rgb332}; end
                                2'b01: begin sdram_wstrb <= 4'b0010; sdram_din <= {16'd0, gpu_rgb332, 8'd0}; end
                                2'b10: begin sdram_wstrb <= 4'b0100; sdram_din <= {8'd0, gpu_rgb332, 16'd0}; end
                                2'b11: begin sdram_wstrb <= 4'b1000; sdram_din <= {gpu_rgb332, 24'd0}; end
                            endcase
                            sdram_wr <= 1;
                            arb_next_state <= ARB_WRITE_GPU;
                            arb_state <= ARB_WAIT_BUSY;
                        end else begin
                            // Read-Modify-Write (GCOL 1..4), Pixel Readback (POINT), or 32-bit Screen Blit (*SSAVE / *SLOAD)
                            sdram_addr <= (gpu_gcol_mode == 3'd7) ? {1'b0, gpu_color[3:0], gpu_word_addr[15:0]} : gpu_word_addr;
                            sdram_rd <= 1;
                            arb_next_state <= ARB_RMW_GPU;
                            arb_state <= ARB_WAIT_BUSY;
                        end
                    end else if (lb_read_req) begin
                        sdram_addr <= (lb_fetch_y * 160) + lb_fetch_col;
                        sdram_rd <= 1;
                        lb_read_ack_reg <= 1;
                        arb_next_state <= ARB_READ;
                        arb_state <= ARB_WAIT_BUSY;
                    end else if (rd_req_sync[2] != rd_ack_toggle) begin
                        // Upper 4 MB of SDRAM (addr[20] = 1'b1)
                        sdram_addr <= {1'b1, rd_req_addr[21:2]};
                        rd_byte_sel <= rd_req_addr[1:0];
                        if (rd_req_we) begin
                            case (rd_req_addr[1:0])
                                2'b00: begin sdram_wstrb <= 4'b0001; sdram_din <= {24'd0, rd_req_wdata}; end
                                2'b01: begin sdram_wstrb <= 4'b0010; sdram_din <= {16'd0, rd_req_wdata, 8'd0}; end
                                2'b10: begin sdram_wstrb <= 4'b0100; sdram_din <= {8'd0, rd_req_wdata, 16'd0}; end
                                2'b11: begin sdram_wstrb <= 4'b1000; sdram_din <= {rd_req_wdata, 24'd0}; end
                            endcase
                            sdram_wr <= 1;
                            arb_next_state <= ARB_WRITE_CPU;
                        end else begin
                            sdram_rd <= 1;
                            arb_next_state <= ARB_READ_CPU;
                        end
                        arb_state <= ARB_WAIT_BUSY;
                    end
                end
                ARB_WAIT_BUSY: begin
                    arb_state <= arb_next_state;
                end
                ARB_REFRESH: begin
                    if (!sdram_busy) begin
                        arb_state <= ARB_IDLE;
                    end
                end
                ARB_WRITE: begin
                    if (!sdram_busy) begin
                        uart_write_ack_reg <= 1;
                        arb_state <= ARB_IDLE;
                    end
                end
                ARB_WRITE_GPU: begin
                    if (!sdram_busy) begin
                        gpu_ack <= 1;
                        arb_state <= ARB_IDLE;
                    end
                end
                ARB_RMW_GPU: begin
                    if (sdram_data_ready) begin
                        gpu_read_pixel <= mapped_read_px;
                        if (gpu_gcol_mode == 3'd5) begin
                            // POINT(X,Y) pixel readback complete
                            gpu_ack <= 1;
                            arb_state <= ARB_IDLE;
                        end else if (gpu_gcol_mode >= 3'd6) begin
                            // *SSAVE (mode 6: Screen -> Slot) or *SLOAD (mode 7: Slot -> Screen) 32-bit word copy
                            sdram_addr <= (gpu_gcol_mode == 3'd6) ? {1'b0, gpu_color[3:0], rmw_word_addr[15:0]} : rmw_word_addr;
                            sdram_din <= sdram_dout;
                            sdram_wstrb <= 4'b1111;
                            arb_state <= ARB_RMW_WRITE;
                        end else begin
                            // GCOL 1..4 Read-Modify-Write (OR, AND, XOR, INVERT)
                            sdram_addr <= rmw_word_addr;
                            case (rmw_byte_sel)
                                2'b00: begin sdram_wstrb <= 4'b0001; sdram_din <= {24'd0, rmw_px}; end
                                2'b01: begin sdram_wstrb <= 4'b0010; sdram_din <= {16'd0, rmw_px, 8'd0}; end
                                2'b10: begin sdram_wstrb <= 4'b0100; sdram_din <= {8'd0, rmw_px, 16'd0}; end
                                2'b11: begin sdram_wstrb <= 4'b1000; sdram_din <= {rmw_px, 24'd0}; end
                            endcase
                            arb_state <= ARB_RMW_WRITE;
                        end
                    end
                end
                ARB_RMW_WRITE: begin
                    sdram_wr <= 1;
                    arb_next_state <= ARB_WRITE_GPU;
                    arb_state <= ARB_WAIT_BUSY;
                end
                ARB_READ: begin
                    if (sdram_data_ready) begin
                        lb_wdata_reg <= sdram_dout;
                        lb_we_reg <= 1;
                        arb_state <= ARB_IDLE;
                    end
                end
                ARB_WRITE_CPU: begin
                    if (!sdram_busy) begin
                        rd_ack_toggle <= rd_req_sync[2];
                        arb_state <= ARB_IDLE;
                    end
                end
                ARB_READ_CPU: begin
                    if (sdram_data_ready) begin
                        case (rd_byte_sel)
                            2'b00: rd_rdata <= sdram_dout[7:0];
                            2'b01: rd_rdata <= sdram_dout[15:8];
                            2'b10: rd_rdata <= sdram_dout[23:16];
                            2'b11: rd_rdata <= sdram_dout[31:24];
                        endcase
                        rd_ack_toggle <= rd_req_sync[2];
                        arb_state <= ARB_IDLE;
                    end
                end
            endcase
        end
    end

    // ==========================================
    // SDRAM Controller Instantiation
    // ==========================================
    sdram #(
        .FREQ(74_250_000)
    ) sdram_inst (
        .clk        (clk),
        .clk_sdram  (~clk),
        .resetn     (rst_n),
        .rd         (sdram_rd),
        .wr         (sdram_wr),
        .refresh    (sdram_refresh),
        .addr       (sdram_addr),
        .din        (sdram_din),
        .wstrb      (sdram_wstrb),
        .dout       (sdram_dout),
        .data_ready (sdram_data_ready),
        .busy       (sdram_busy),
        
        .SDRAM_DQ   (IO_sdram_dq),
        .SDRAM_A    (O_sdram_addr),
        .SDRAM_BA   (O_sdram_ba),
        .SDRAM_nCS  (O_sdram_cs_n),
        .SDRAM_nWE  (O_sdram_wen_n),
        .SDRAM_nRAS (O_sdram_ras_n),
        .SDRAM_nCAS (O_sdram_cas_n),
        .SDRAM_CLK  (O_sdram_clk),
        .SDRAM_CKE  (O_sdram_cke),
        .SDRAM_DQM  (O_sdram_dqm)
    );

endmodule
