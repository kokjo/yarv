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

    parameter DEPTH=10;
    localparam WORDS = 1 << DEPTH;

    reg [31:0] ram [0:WORDS-1];
    integer i;
    
    always @ (posedge clk) begin
        mem_ready <= 0;
        if(mem_valid && !mem_ready) begin
            mem_rdata <= ram[mem_addr >> 2];
            for(i = 0; i < 4; i += 1)
                if(mem_wstrb[i])
                    ram[mem_addr >> 2][i*8 +: 8] <= mem_wdata[i*8 +: 8];
        end
    end
endmodule
