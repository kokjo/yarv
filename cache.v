module icache (
    clk, rstn,
    cache_flush,
    cache_valid, cache_ready, cache_addr, cache_rdata,
    mem_valid, mem_ready, mem_addr, mem_rdata
);
    parameter DEPTH = 4;
    localparam WORDS = 1 << DEPTH;

    input clk, rstn;
    input cache_flush;

    input cache_valid;
    output cache_ready;
    input [31:0] cache_addr;
    output [31:0] cache_rdata;

    output mem_valid;
    input mem_ready;
    output [31:0] mem_addr;
    input [31:0] mem_rdata;

    wire [DEPTH-1:0] tag = cache_addr[DEPTH-1+2:2];

    reg [WORDS-1:0] valid;
    reg [31:0] match [WORDS-1:0];
    reg [31:0] cache [WORDS-1:0];

    wire cache_hit = cache_valid && (valid[tag] && match[tag] == cache_addr);

    assign cache_ready = cache_hit || mem_ready;
    assign cache_rdata = mem_valid ? mem_rdata : cache[tag];

    assign mem_addr = cache_addr;
    assign mem_valid = cache_valid && !cache_hit;

    always @ (posedge clk) if(!rstn) begin
        valid <= 0;
    end else begin
        if(cache_flush) valid <= 0;
        if(mem_valid && mem_ready) begin
            valid[tag] <= 1;
            match[tag] <= cache_addr;
            cache[tag] <= mem_rdata;
        end
    end
endmodule
