module hardware (
    input clk,

    output user_led,

    output flash_csb,
    output flash_clk,
    inout  flash_io0,
    inout  flash_io1,
    inout  flash_io2,
    inout  flash_io3
);

    reg [5:0] reset_cnt = 0;
    wire rst = !(&reset_cnt);
    always @ (posedge clk) reset_cnt = reset_cnt + rst;

    wire flash_io0_oe, flash_io0_do, flash_io0_di;
    wire flash_io1_oe, flash_io1_do, flash_io1_di;
    wire flash_io2_oe, flash_io2_do, flash_io2_di;
    wire flash_io3_oe, flash_io3_do, flash_io3_di;

    SB_IO #(
        .PIN_TYPE(6'b 1010_01),
        .PULLUP(1'b 0)
    ) flash_io_buf [3:0] (
        .PACKAGE_PIN({flash_io3, flash_io2, flash_io1, flash_io0}),
        .OUTPUT_ENABLE({flash_io3_oe, flash_io2_oe, flash_io1_oe, flash_io0_oe}),
        .D_OUT_0({flash_io3_do, flash_io2_do, flash_io1_do, flash_io0_do}),
        .D_IN_0({flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di})
    );

/*
    SB_IO #(
        .PIN_TYPE(6'b101001),
        .PULLUP(1'b0)
    ) gpio_io_buf [24:0] (
        .PACKAGE_PIN({pin_1, pin_2, pin_3, pin_4, pin_5, pin_6, pin_7, pin_8, pin_9, pin_10, pin_11, pin_12, pin_13,
                      pin_14, pin_15, pin_16, pin_17, pin_18, pin_19, pin_20, pin_21, pin_22, pin_23, pin_24, user_led}),
        .OUTPUT_ENABLE(gpio_oe[24:0]),
        .D_OUT_0(gpio_do[24:0]),
        .D_IN_0(gpio_di[24:0])
    );

*/

    wire iomem_valid;
    wire iomem_ready;
    wire [31:0] iomem_addr;
    wire [31:0] iomem_rdata;
    wire [31:0] iomem_wdata;
    wire [31:0] iomem_wstrb;

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

    
endmodule
