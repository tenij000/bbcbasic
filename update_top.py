import sys

with open('src/top.v', 'r') as f:
    content = f.read()

start_marker = '    // --- 6502 CPU & RAM/ROM ---'
end_marker = '    cpu cpu_inst ('

if start_marker in content and end_marker in content:
    pre = content[:content.find(start_marker)]
    post = content[content.find(end_marker):]
    
    new_logic = """    // --- 6502 CPU & RAM/ROM ---
    wire [15:0] cpu_ab;
    wire [7:0]  cpu_do;
    reg  [7:0]  cpu_di;
    wire        cpu_we;
    
    // Memory (8KB RAM, 8KB ROM)
    reg [7:0] cpu_ram [0:8191];
    reg [7:0] cpu_rom [0:8191];
    
    initial begin
        $readmemh("ehbasic.hex", cpu_rom);
    end
    
    // UART TX from CPU (CPU printing to terminal)
    reg [7:0] term_rx_data_cpu;
    reg       term_rx_valid_cpu;
    
    // UART RX to CPU (CPU reading keyboard)
    reg [7:0] kbd_data;
    reg       kbd_ready;
    
    always @(posedge sys_clk) begin
        // If in terminal mode and we get UART data (excluding magic seq), feed to CPU
        if (uart_valid && (uart_mode == 0)) begin
            kbd_data <= uart_data;
            kbd_ready <= 1;
        end
        
        // RAM write (0x0000 - 0x1FFF)
        if (cpu_we && cpu_ab < 16'h2000) begin
            cpu_ram[cpu_ab[12:0]] <= cpu_do;
        end
        
        // ACIA Data write (0xFFD1)
        term_rx_valid_cpu <= 0;
        if (cpu_we && cpu_ab == 16'hFFD1) begin
            term_rx_data_cpu <= cpu_do;
            term_rx_valid_cpu <= 1;
        end
        
        // ACIA Data read clears status (0xFFD1)
        if (!cpu_we && cpu_ab == 16'hFFD1) begin
            kbd_ready <= 0;
        end
    end
    
    // Address decoding for CPU DI (Synchronous for BRAM inference)
    always @(posedge sys_clk) begin
        if (cpu_ab < 16'h2000) begin
            cpu_di <= cpu_ram[cpu_ab[12:0]];
        end else if (cpu_ab >= 16'hE000) begin
            cpu_di <= cpu_rom[cpu_ab[12:0]]; // E000-FFFF is 8KB
        end else if (cpu_ab == 16'hFFD0) begin
            // ACIA Status: Bit 1 = TX Empty, Bit 0 = RX Full
            cpu_di <= {6'b000000, 1'b1, kbd_ready};
        end else if (cpu_ab == 16'hFFD1) begin
            cpu_di <= kbd_data;
        end else begin
            cpu_di <= 8'hEA; // NOP for unmapped memory
        end
    end
    
"""
    with open('src/top.v', 'w') as f:
        f.write(pre + new_logic + post)
    print('top.v overschreven met Grant Searle 6502 map!')
else:
    print('Kon de markers niet vinden in top.v')
