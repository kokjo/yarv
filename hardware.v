module hardware (
    input clk_16mhz,

    inout user_led,

    output flash_csb,
    output flash_clk,
    inout  flash_io0,
    inout  flash_io1,
    inout  flash_io2,
    inout  flash_io3
);
    wire clk = clk_16mhz;
    reg [5:0] reset_cnt = 0;
    wire rst = !(&reset_cnt);
    always @ (posedge clk) reset_cnt = reset_cnt + rst;

    wire flash_io0_oe, flash_io0_do, flash_io0_di;
    wire flash_io1_oe, flash_io1_do, flash_io1_di;
    wire flash_io2_oe, flash_io2_do, flash_io2_di;
    wire flash_io3_oe, flash_io3_do, flash_io3_di;

    wire iomem_valid;
    wire [31:0] iomem_addr;
    wire [31:0] iomem_wdata;
    wire [31:0] iomem_wstrb;

    wire gpio_valid = iomem_valid && iomem_addr[31:16] == 28'h0300;
    wire gpio_ready;
    wire [31:0] gpio_rdata;

    wire iomem_ready = (gpio_valid && gpio_ready);
    wire [31:0] iomem_rdata = gpio_valid ? gpio_rdata : 32'h00000000;

    soc soc (
        .clk(clk), .rst(rst),
        .iomem_valid(iomem_valid), .iomem_ready(iomem_ready),
        .iomem_addr(iomem_addr), .iomem_rdata(iomem_rdata),
        .iomem_wdata(iomem_wdata), .iomem_wstrb(iomem_wstrb),

        .flash_csb(flash_csb), .flash_clk(flash_clk),

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
        .flash_io3_di(flash_io3_di)
    );

    SB_IO #(
        .PIN_TYPE(6'b 1010_01),
        .PULLUP(1'b 0)
    ) flash_io_buf [3:0] (
        .PACKAGE_PIN({flash_io3, flash_io2, flash_io1, flash_io0}),
        .OUTPUT_ENABLE({flash_io3_oe, flash_io2_oe, flash_io1_oe, flash_io0_oe}),
        .D_OUT_0({flash_io3_do, flash_io2_do, flash_io1_do, flash_io0_do}),
        .D_IN_0({flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di})
    );

    wire [31:0] gpio_oe;
    wire [31:0] gpio_do;
    wire [31:0] gpio_di;

    mem_gpio gpio (
        .clk(clk), .rst(rst),
        .mem_valid(gpio_valid),
        .mem_ready(gpio_ready),
        .mem_rdata(gpio_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),

        .gpio_oe(gpio_oe),
        .gpio_do(gpio_do),
        .gpio_di(gpio_di)
    );

    SB_IO #(
        .PIN_TYPE(6'b101001),
        .PULLUP(1'b0)
    ) gpio_led_buf (
        .PACKAGE_PIN(user_led),
        .OUTPUT_ENABLE(gpio_oe[0]),
        .D_OUT_0(gpio_do[0]),
        .D_IN_0(gpio_di[0])
    );

endmodule
