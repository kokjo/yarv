module mem_gpio (
    clk, rst,
    mem_valid, mem_ready,
    mem_addr, mem_rdata,
    mem_wdata, mem_wstrb,

    gpio_oe, gpio_do, gpio_di,
    alt_oe, alt_do, alt_di
);
    input clk, rst;

    input mem_valid;
    output reg mem_ready;
    input [31:0] mem_addr;
    output reg [31:0] mem_rdata;
    input [31:0] mem_wdata;
    input [3:0] mem_wstrb;

    output [31:0] gpio_oe;
    output [31:0] gpio_do;
    input [31:0] gpio_di;

    input [31:0] alt_oe;
    input [31:0] alt_do;
    output [31:0] alt_di;

    reg [31:0] alt_en;

    reg [31:0] gpio_oe_r;
    reg [31:0] gpio_do_r;

    genvar i;
    generate
        for(i = 0; i < 32; i = i + 1) begin
            assign gpio_oe[i] = alt_en[i] ? alt_oe[i]  : gpio_oe_r[i];
            assign gpio_do[i] = alt_en[i] ? alt_do[i]  : gpio_do_r[i];
            assign alt_di[i]  = alt_en[i] ? gpio_di[i] : 1'b0;
        end
    endgenerate

    wire mem_write = &mem_wstrb;
    
    always @ (posedge clk) if(rst) begin
        gpio_oe_r <= 32'h00000000;
        gpio_do_r <= 32'h00000000;
        alt_en <= 32'h00000000;
        mem_ready <= 0;
        mem_rdata <= 32'h00000000;
    end else begin
        mem_ready <= 0;
        if(mem_valid && !mem_ready) begin
            mem_ready <= 1;
            if(mem_addr[3:0] == 4'h0) begin
                mem_rdata <= alt_en;
                if(mem_write) alt_en <= mem_wdata;
            end
            if(mem_addr[3:0] == 4'h4) begin
                mem_rdata <= gpio_oe_r;
                if(mem_write) gpio_oe_r <= mem_wdata;
            end
            if(mem_addr[3:0] == 4'h8) begin
                mem_rdata <= gpio_di;
                if(mem_write) gpio_do_r <= mem_wdata;
            end
        end
    end
endmodule
