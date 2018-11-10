module soc (
    clk, rst,

    iomem_valid,
    iomem_ready,
    iomem_addr,
    iomem_rdata,
    iomem_wdata,
    iomem_wstrb,

    flash_csb,
    flash_clk, 

    flash_io0_oe,
    flash_io1_oe,
    flash_io2_oe,
    flash_io3_oe,

    flash_io0_do,
    flash_io1_do,
    flash_io2_do,
    flash_io3_do,

    flash_io0_di,
    flash_io1_di,
    flash_io2_di,
    flash_io3_di
);
    parameter RAM_DEPTH = 8;
    parameter ICACHE_DEPTH = 8;
    parameter RESET_PC = 32'h00050000;
    localparam RAM_WORDS = 1 << RAM_DEPTH;

    input clk;
    input rst;

    output        iomem_valid;
    input         iomem_ready;
    output [31:0] iomem_addr;
    input  [31:0] iomem_rdata;
    output [31:0] iomem_wdata;
    output [ 3:0] iomem_wstrb;

    output flash_csb;
    output flash_clk;

    output flash_io0_oe;
    output flash_io1_oe;
    output flash_io2_oe;
    output flash_io3_oe;

    output flash_io0_do;
    output flash_io1_do;
    output flash_io2_do;
    output flash_io3_do;

    input  flash_io0_di;
    input  flash_io1_di;
    input  flash_io2_di;
    input  flash_io3_di;

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;

    wire ram_valid = mem_valid && mem_addr < RAM_WORDS*4;
    wire ram_ready;
    wire [31:0] ram_rdata;

    wire spimem_valid = mem_valid && mem_addr >= RAM_WORDS*4 && mem_addr < 32'h 02000000;
    wire spimem_ready;
    wire [31:0] spimem_rdata;

    wire spimemio_cfgreg_sel = mem_valid && mem_addr == 32'h02000000;
    wire [31:0] spimemio_cfgreg_do;

    wire simpleuart_reg_div_sel = mem_valid && (mem_addr == 32'h 0200_0004);
    wire [31:0] simpleuart_reg_div_do;

    wire simpleuart_reg_dat_sel = mem_valid && (mem_addr == 32'h 0200_0008);
    wire [31:0] simpleuart_reg_dat_do;
    wire simpleuart_reg_dat_wait;


    assign iomem_valid = mem_valid && mem_addr >= 32'h03000000;
    assign iomem_addr = mem_addr;
    assign iomem_wdata = mem_wdata;
    assign iomem_wstrb = mem_wstrb;

    wire [31:0] mem_rdata = spimem_valid ? spimem_rdata
                          : ram_valid ? ram_rdata
                          : iomem_valid ? iomem_rdata
                          : spimemio_cfgreg_sel ? spimemio_cfgreg_do
                          : simpleuart_reg_div_sel ? simpleuart_reg_div_do
                          : simpleuart_reg_dat_sel ? simpleuart_reg_dat_do
                          : 32'h00000000;

    wire mem_ready = (spimem_valid & spimem_ready)
                   | (ram_valid & ram_ready)
                   | (iomem_valid & iomem_ready)
                   | spimemio_cfgreg_sel
                   | simpleuart_reg_div_sel
                   | (simpleuart_reg_dat_sel && !simpleuart_reg_dat_wait);

    core #(
        .RESET_PC(RESET_PC),
        .ICACHE_DEPTH(ICACHE_DEPTH)
    ) core (
        .clk(clk), .rst(rst),
        .mem_valid(mem_valid),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb)
    );

    ram #(
        .DEPTH(RAM_DEPTH)
    ) ram0 (
        .clk(clk),
        .mem_valid(ram_valid),
        .mem_ready(ram_ready),
        .mem_addr(mem_addr),
        .mem_rdata(ram_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb)
    );

    spimemio spimemio (
        .clk(clk),
        .resetn(!rst),
        .valid(spimem_valid),
        .ready(spimem_ready),
        .addr(mem_addr[23:0]),
        .rdata(spimem_rdata),

        .flash_csb(flash_csb   ),
        .flash_clk(flash_clk   ),

        .flash_io0_oe(flash_io0_oe),
        .flash_io1_oe(flash_io1_oe),
        .flash_io2_oe(flash_io2_oe),
        .flash_io3_oe(flash_io3_oe),

        .flash_io0_do(flash_io0_do),
        .flash_io1_do(flash_io1_do),
        .flash_io2_do(flash_io2_do),
        .flash_io3_do(flash_io3_do),

        .flash_io0_di(flash_io0_di),
        .flash_io1_di(flash_io1_di),
        .flash_io2_di(flash_io2_di),
        .flash_io3_di(flash_io3_di),

        .cfgreg_we(spimemio_cfgreg_sel ? mem_wstrb : 4'b 0000),
        .cfgreg_di(mem_wdata),
        .cfgreg_do(spimemio_cfgreg_do)
    );

    simpleuart simpleuart (
        .clk(clk),
        .resetn(!rst),

        .ser_tx(ser_tx      ),
        .ser_rx(ser_rx      ),

        .reg_div_we(simpleuart_reg_div_sel ? mem_wstrb : 4'b 0000),
        .reg_div_di(mem_wdata),
        .reg_div_do(simpleuart_reg_div_do),

        .reg_dat_we(simpleuart_reg_dat_sel ? mem_wstrb[0] : 1'b 0),
        .reg_dat_re(simpleuart_reg_dat_sel && !mem_wstrb),
        .reg_dat_di(mem_wdata),
        .reg_dat_do(simpleuart_reg_dat_do),
        .reg_dat_wait(simpleuart_reg_dat_wait)
    );
endmodule
