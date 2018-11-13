module arb (
    input clk,
    input rstn,

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
    output reg mem_valid,
    input mem_ready,
    output reg [31:0] mem_addr,
    input [31:0] mem_rdata,
    output reg [31:0] mem_wdata,
    output reg [3:0] mem_wstrb
);
    localparam IDLE = 0;
    localparam SLAVE0 = 1;
    localparam SLAVE1 = 2;

    reg [1:0] state = IDLE;

    //assign mem_valid = state == SLAVE0 || state == SLAVE1;
    //assign mem_addr  = state == SLAVE0 ? mem0_addr : mem1_addr;
    //assign mem_wdata = state == SLAVE0 ? mem0_wdata : mem1_wdata;
    //assign mem_wstrb = state == SLAVE0 ? mem0_wstrb : mem1_wstrb;

    assign mem0_ready = state == SLAVE0 && mem_ready;
    assign mem0_rdata = mem_rdata;

    assign mem1_ready = state == SLAVE1 && mem_ready;
    assign mem1_rdata = mem_rdata;

/*
    wire next_state = rst ? IDLE
                    : (state == IDLE && mem0_valid) ? SLAVE0
                    : (state == IDLE && mem1_valid) ? SLAVE1
                    : (state == SLAVE0 && mem_ready) ? (mem1_valid ? SLAVE1 : IDLE)
                    : (state == SLAVE1 && mem_ready) ? (mem0_valid ? SLAVE0 : IDLE)
                    : state;

    always @ (posedge clk) state <= next_state;
*/

    always @ (posedge clk) if(!rstn) begin
        state <= IDLE;
    end else begin
        case(state)
            IDLE: begin
                if(mem1_valid) begin
                    mem_valid <= 1;
                    mem_addr <= mem1_addr;
                    mem_wdata <= mem1_wdata;
                    mem_wstrb <= mem1_wstrb;
                    state <= SLAVE1;
                end
                if(mem0_valid) begin
                    mem_valid <= 1;
                    mem_addr <= mem0_addr;
                    mem_wdata <= mem0_wdata;
                    mem_wstrb <= mem0_wstrb;
                    state <= SLAVE0;
                end
            end
            SLAVE0:
                if(mem_ready) begin
                    mem_valid <= 0;
                    mem_addr <= 32'hxxxxxxxx;
                    mem_wdata <= 32'hxxxxxxxx;
                    mem_wstrb <= 32'hxxxxxxxx;
                    state <= IDLE;
                end
            SLAVE1:
                if(mem_ready) begin
                    mem_valid <= 0;
                    mem_addr <= 32'hxxxxxxxx;
                    mem_wdata <= 32'hxxxxxxxx;
                    mem_wstrb <= 32'hxxxxxxxx;
                    state <= IDLE;
                end
        endcase
    end
endmodule
