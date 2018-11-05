module soc (
    clk, rst, led
);
    input clk;
    input rst;
    output led;

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;

    wire rom_valid = mem_valid && mem_addr[31:24] == 8'h00;
    wire rom_ready;
    wire [31:0] rom_rdata;

    wire ram_valid = mem_valid && mem_addr[31:24] == 8'h01;
    wire ram_ready;
    wire [31:0] ram_rdata;

    wire [31:0] mem_rdata = rom_valid ? rom_rdata
                          : ram_valid ? ram_rdata
                          : 32'h00000000;
    wire mem_ready = (rom_valid && rom_ready) || (ram_valid && ram_ready);

    rom rom0 (
        .clk(clk),
        .mem_valid(rom_valid),
        .mem_ready(rom_ready),
        .mem_addr(mem_addr),
        .mem_rdata(rom_rdata)
    );
    
    ram ram0 (
        .clk(clk),
        .mem_valid(ram_valid),
        .mem_ready(ram_ready),
        .mem_addr(mem_addr),
        .mem_rdata(ram_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb)
    );

    core core (
        .clk(clk), .rst(rst), .fault(led),
        .mem_valid(mem_valid),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb)
    );
endmodule
