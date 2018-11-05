module arb (
    input clk,
    input rst,

    // memory slave interface 0
    input mem0_valid,
    output mem0_ready,
    input [31:0] mem0_addr,
    output [31:0] mem0_rdata,
    input [31:0] mem0_wdata,
    input [3:0] mem0_wstrb,

    // memory slave interface 1
    input mem1_valid,
    output mem1_ready,
    input [31:0] mem1_addr,
    output [31:0] mem1_rdata,
    input [31:0] mem1_wdata,
    input [3:0] mem1_wstrb,

    // memory master interface
    output mem_valid,
    input mem_ready,
    output [31:0] mem_addr,
    input [31:0] mem_rdata,
    output [31:0] mem_wdata,
    output [3:0] mem_wstrb
);
    localparam IDLE = 0;
    localparam SLAVE0 = 1;
    localparam SLAVE1 = 2;
    reg [1:0] state = IDLE;

    assign mem_valid = state == SLAVE0 || state == SLAVE1; 
    assign mem_addr  = state == SLAVE0 ? mem0_addr : mem1_addr;
    assign mem_wdata = state == SLAVE0 ? mem0_wdata : mem1_wdata;
    assign mem_wstrb = state == SLAVE0 ? mem0_wstrb : mem1_wstrb;

    assign mem0_ready = state == SLAVE0 && mem_ready;
    assign mem0_rdata = mem_rdata;

    assign mem1_ready = state == SLAVE1 && mem_ready;
    assign mem1_rdata = mem_rdata;

    always @ (posedge clk) if(rst) begin
        state <= IDLE;
    end else begin
        case(state)
            IDLE: begin
                if(mem1_valid) state <= SLAVE1;
                if(mem0_valid) state <= SLAVE0;
            end
            SLAVE0:
                if(mem_ready) state <= IDLE;
            SLAVE1:
                if(mem_ready) state <= mem0_valid ? SLAVE0 : IDLE;
        endcase
    end
endmodule
