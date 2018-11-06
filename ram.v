module ram (
    clk,
    mem_valid, mem_ready,
    mem_addr, mem_rdata,
    mem_wdata, mem_wstrb
);
    input clk;
    input mem_valid;
    output reg mem_ready;
    input [31:0] mem_addr;
    output reg [31:0] mem_rdata;
    input [31:0] mem_wdata;
    input [3:0] mem_wstrb;

    parameter DEPTH = 8;
    localparam WORDS = 1 << DEPTH;

    reg [31:0] memory [WORDS-1:0];
    integer i;

    initial for(i = 0; i < WORDS; i = i + 1) memory[i] <= 32'h00000000;

    wire [DEPTH-1: 0] addr = mem_addr[DEPTH-1 + 2: 2];
    
    always @ (posedge clk) begin
        mem_ready <= 0;
        if(mem_valid && !mem_ready) begin
            mem_ready <= 1;
            mem_rdata <= memory[addr];
            if(mem_wstrb[0]) memory[addr][7:0] <= mem_wdata[7:0];
            if(mem_wstrb[1]) memory[addr][15:8] <= mem_wdata[15:8];
            if(mem_wstrb[2]) memory[addr][23:16] <= mem_wdata[23:16];
            if(mem_wstrb[3]) memory[addr][31:24] <= mem_wdata[31:24];
        end
    end
endmodule
