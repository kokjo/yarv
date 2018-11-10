module testbench();
    reg clk = 1;
    reg rstn = 0;

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;

    wire rom_valid = mem_valid && mem_addr[31:16] == 16'h0005;
    wire rom_ready;
    wire [31:0] rom_rdata;

    wire ram_valid = mem_valid && mem_addr[31:16] == 16'h0000;
    wire ram_ready;
    wire [31:0] ram_rdata;

    wire gpio_valid = mem_valid && mem_addr[31:16] == 16'h0300;
    wire gpio_ready;
    wire [31:0] gpio_rdata;

    wire [31:0] mem_rdata = rom_valid ? rom_rdata
                          : ram_valid ? ram_rdata
                          : gpio_valid ? gpio_rdata
                          : 32'h00000000;

    wire mem_ready = (rom_valid & rom_ready)
                   | (ram_valid & ram_ready)
                   | (gpio_valid & gpio_ready);

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

    core #(
        .RESET_PC(32'h00050000)
    ) core (
        .clk(clk), .rstn(rstn),
        .mem_valid(mem_valid),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb)
    );

    wire [31:0] gpio_oe;
    wire [31:0] gpio_do;
    wire [31:0] gpio_di = 32'h5a5a5a5a;

    mem_gpio gpio (
        .clk(clk), .rstn(rstn),
        .mem_valid(gpio_valid),
        .mem_ready(gpio_ready),
        .mem_addr(mem_addr),
        .mem_rdata(gpio_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),

        .gpio_oe(gpio_oe),
        .gpio_do(gpio_do),
        .gpio_di(gpio_di)
    );

    always clk = #1 !clk;

    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars;
        #2
        rstn = 1;
        #10000
        $finish;
    end

endmodule
