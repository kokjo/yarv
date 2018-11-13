module fetch(
    // control signals
    input clk, input rstn, input hlt,
    // branch control
    input override, input [31:0] newpc,
    // memory read interface
    output mem_valid, output [31:0] mem_addr, input [31:0] mem_rdata,
    // pipeline registers
    output reg [31:0] instruction, output reg [31:0] outpc
);
    wire [31:0] pc;
    wire [31:0] next_pc;
    
    parameter RESET_PC = 32'h00000000;
    parameter RESET_INSTRUCTION = 32'h00000000;

    programcounter #(
        .RESET_PC(RESET_PC)
    ) pc0 (
        .clk(clk), .rstn(rstn), .hlt(hlt),
        .override(override), .newpc(newpc),
        .pc(pc)
    );

    assign mem_addr = pc;
    assign mem_valid = 1;

    always @ (posedge clk) if(!rstn) begin
        instruction <= RESET_INSTRUCTION;
        outpc <= RESET_PC;
    end else if(!hlt) begin
        outpc <= pc;
        instruction <= mem_rdata;
    end
endmodule

module programcounter (
    input clk, input rstn, input hlt,
    input override, input [31:0] newpc,
    output reg [31:0] pc
);
    parameter RESET_PC = 32'h00000000;

    always @ (posedge clk) if(!rstn) begin
        pc <= RESET_PC;
    end else if (!hlt) begin
        pc <= override ? newpc : pc + 4;
    end
endmodule
