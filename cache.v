module cache (
    clk, rst,
    cache_valid, cache_ready, cache_addr, cache_rdata,
    mem_valid, mem_ready, mem_addr, mem_rdata
);
    parameter DEPTH = 6;
    localparam WORDS = 1 << DEPTH;

    input clk, rst;

    input cache_valid;
    output cache_ready;
    input [31:0] cache_addr;
    output [31:0] cache_rdata;

    output reg mem_valid;
    input mem_ready;
    output [31:0] mem_addr;
    input [31:0] mem_rdata;

    wire [DEPTH-1:0] tag = cache_addr[DEPTH-1+2:2];

    reg [WORDS-1:0] valid;
    reg [31:0] match [WORDS-1:0];
    reg [31:0] cache [WORDS-1:0];

    assign cache_ready = valid[tag] && match[tag] == cache_addr;
    assign cache_rdata = cache[tag];

    assign mem_addr = cache_addr;

    wire do_fetch = cache_valid && !cache_ready;

    always @ (posedge clk) if(rst) begin
        valid <= 0;
    end else begin
        if(do_fetch) begin
            mem_valid <= 1;
            if(mem_ready) begin
                valid[tag] <= 1;
                match[tag] <= cache_addr;
                cache[tag] <= mem_rdata;
                mem_valid <= 0;
            end
        end
    end
endmodule
