module core (
    clk, rstn, fault,
    mem_valid, mem_ready,
    mem_addr, mem_rdata,
    mem_wdata, mem_wstrb,
);
    parameter RESET_PC = 32'h00000000;
    parameter ICACHE_DEPTH = 8;

    input clk, rstn;
    output reg fault;

    output mem_valid;
    input mem_ready;
    output [31:0] mem_addr;
    input [31:0] mem_rdata;
    output [31:0] mem_wdata;
    output [3:0] mem_wstrb;

    wire mem0_valid;
    wire mem0_ready;
    wire [31:0] mem0_addr;
    wire [31:0] mem0_rdata;

    wire mem1_valid;
    wire mem1_ready;
    wire [31:0] mem1_addr;
    wire [31:0] mem1_rdata;
    wire [31:0] mem1_wdata;
    wire [3:0] mem1_wstrb;

    arb arb0 (
        .clk(clk), .rstn(rstn),
        .mem0_valid(mem0_valid),
        .mem0_ready(mem0_ready),
        .mem0_addr(mem0_addr),
        .mem0_rdata(mem0_rdata),
        .mem0_wdata(32'h00000000),
        .mem0_wstrb(4'b0000),

        .mem1_valid(mem1_valid),
        .mem1_ready(mem1_ready),
        .mem1_addr(mem1_addr),
        .mem1_rdata(mem1_rdata),
        .mem1_wdata(mem1_wdata),
        .mem1_wstrb(mem1_wstrb),
    
        .mem_valid(mem_valid),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb)
    );

    wire icache_flush;
    wire icache_valid;
    wire icache_ready;
    wire [31:0] icache_addr;
    wire [31:0] icache_rdata;

    icache #(
        .DEPTH(ICACHE_DEPTH)
    ) icache(
        .clk(clk), .rstn(rstn),
        .cache_flush(icache_flush),
        .cache_valid(icache_valid),
        .cache_ready(icache_ready),
        .cache_addr(icache_addr),
        .cache_rdata(icache_rdata),
        .mem_valid(mem0_valid),
        .mem_ready(mem0_ready),
        .mem_addr(mem0_addr),
        .mem_rdata(mem0_rdata)
    );

    wire hlt = (icache_valid & !icache_ready) | (mem1_valid & !mem1_ready) | fault;
    wire execute_fault;

    wire override;
    wire [31:0] newpc;
    
    wire [31:0] instruction;
    wire [31:0] fetch_pc;

    fetch #(
        .RESET_PC(RESET_PC)
    ) fetcher (
        .clk(clk), .rstn(rstn), .hlt(hlt),
        .override(override), .newpc(newpc),
        .mem_valid(icache_valid),
        .mem_addr(icache_addr),
        .mem_rdata(icache_rdata),
        .instruction(instruction),
        .outpc(fetch_pc)
    );

    wire [31:0] imms;
    wire [31:0] immu;
    wire [6:0] opcode;
    wire [4:0] rd;
    wire [2:0] funct3;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [6:0] funct7;
    wire load, fence, alui, auipc;
    wire store, alur, lui, branch;
    wire jalr, jal, system;
    wire invalid, unknown;
    wire [31:0] execute_pc;

    decode decoder (
        .clk(clk), .rstn(rstn), .hlt(hlt),
        .instruction(instruction), .inpc(fetch_pc),
        .imms(imms), .immu(immu),
        .opcode(opcode),
        .rd(rd), .funct3(funct3), .rs1(rs1), .rs2(rs2), .funct7(funct7),
        .load(load), .fence(fence), .alui(alui), .auipc(auipc),
        .store(store), .alur(alur), .lui(lui), .branch(branch),
        .jalr(jalr), .jal(jal), .system(system),
        .invalid(invalid), .unknown(unknown),
        .outpc(execute_pc)
    );

    execute executer (
        .clk(clk), .rstn(rstn), .hlt(hlt),
        .imms(imms), .immu(immu),
        .opcode(opcode),
        .rd(rd), .funct3(funct3), .rs1(rs1), .rs2(rs2), .funct7(funct7),
        .load(load), .fence(fence), .alui(alui), .auipc(auipc),
        .store(store), .alur(alur), .lui(lui), .branch(branch),
        .jalr(jalr), .jal(jal), .system(system),
        .invalid(invalid), .unknown(unknown),
        .inpc(execute_pc),
        
        .override(override),
        .newpc(newpc),
        .fault(execute_fault),

        .mem_valid(mem1_valid),
        .mem_ready(mem1_ready),
        .mem_addr(mem1_addr),
        .mem_rdata(mem1_rdata),
        .mem_wdata(mem1_wdata),
        .mem_wstrb(mem1_wstrb)
    );

    assign icache_flush = fence;

    always @ (posedge clk) if(!rstn) begin
        fault <= 0;
    end else if(execute_fault) begin
        fault <= 1;
    end
endmodule

