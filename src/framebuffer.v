module framebuffer (
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
    output [23:0] rgb
);

    // 320x180 pixels, each pixel is a 4x4 block on the 1280x720 screen.
    // 320 * 180 = 57600 bytes. Tang Nano 20k has ~103 KB of Block RAM.
    reg [7:0] fb_ram [0:65535]; 

    reg [2:0] state; // 0=X_low, 1=X_high, 2=Y, 3=Color
    reg [8:0] pixel_x;
    reg [7:0] pixel_y;

    wire [16:0] write_py = pixel_y;
    wire [16:0] write_px = pixel_x;
    wire [15:0] write_addr = (write_py << 8) + (write_py << 6) + write_px;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
            pixel_x <= 0;
            pixel_y <= 0;
        end else begin
            if (rx_valid) begin
                if (rx_data == 8'hFF) begin
                    state <= 0; // Sync command
                end else if (state == 0) begin
                    pixel_x[6:0] <= rx_data[6:0];
                    state <= 1;
                end else if (state == 1) begin
                    pixel_x[8:7] <= rx_data[1:0];
                    state <= 2;
                end else if (state == 2) begin
                    pixel_y <= rx_data;
                    state <= 3;
                end else if (state == 3) begin
                    // Write pixel. Address is Y * 320 + X
                    if (pixel_x < 320 && pixel_y < 180) begin
                        fb_ram[write_addr] <= rx_data;
                    end
                    state <= 0;
                end
            end
        end
    end

    // HDMI Read Logic
    // cx is 0..1279, cy is 0..719
    // fb_x = cx / 4
    // fb_y = cy / 4
    wire [8:0] fb_x = cx[10:2];
    wire [7:0] fb_y = cy[9:2];
    
    wire [16:0] read_py = fb_y;
    wire [16:0] read_px = fb_x;
    wire [15:0] read_addr = (read_py << 8) + (read_py << 6) + read_px;
    
    reg [7:0] current_color;
    always @(posedge clk_pixel) begin
        if (fb_x < 320 && fb_y < 180) begin
            current_color <= fb_ram[read_addr];
        end else begin
            current_color <= 8'h00; // Black outside bounds
        end
    end

    // Convert 8-bit RGB (3:3:2) to 24-bit RGB
    // R = 3 bits, G = 3 bits, B = 2 bits
    wire [7:0] r = {current_color[7:5], current_color[7:5], current_color[7:6]};
    wire [7:0] g = {current_color[4:2], current_color[4:2], current_color[4:3]};
    wire [7:0] b = {current_color[1:0], current_color[1:0], current_color[1:0], current_color[1:0]};

    assign rgb = {r, g, b};

endmodule
