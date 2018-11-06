module execute (
    // control signals
    clk, rst, hlt,
    // pipeline input 
    // decoded immediates
    imms, immu,
    // instruction parts,
    opcode, rd, funct3, rs1, rs2, funct7,
    // individual opcodes
    load, fence, alui, auipc,
    store, alur, lui, branch,
    jalr, jal, system,
    // instruction decode fail
    invalid, unknown,
    // pc for next stage
    inpc,
    // branch control signals
    override,
    newpc,
    // fault control signal
    fault,
    // load/store signals
    mem_valid,
    mem_addr,
    mem_rdata,
    mem_wdata,
    mem_wstrb,
);
    input clk, rst, hlt;

    input [31:0] imms;
    input [31:0] immu;
    input [6:0] opcode;
    input [4:0] rd;
    input [2:0] funct3;
    input [4:0] rs1;
    input [4:0] rs2;
    input [6:0] funct7;
    input load, fence, alui, auipc;
    input store, alur, lui, branch;
    input jalr, jal, system;
    input invalid, unknown;
    input [31:0] inpc;

    output override;
    output [31:0] newpc;
    output fault;

    output mem_valid;
    output [31:0] mem_addr;
    input [31:0] mem_rdata;
    output [31:0] mem_wdata;
    output [3:0] mem_wstrb;

    wire [31:0] alu_result;
    wire [31:0] mem_result;
    wire branch_taken;
    wire [31:0] result = auipc ? inpc + imms
                       : lui ? imms 
                       : (alui || alur) ? alu_result
                       : (jal || jalr) ? inpc + 4 
                       : load ? mem_result
                       : 32'h00000000;

    reg [1:0] flush;

    wire write = !hlt && flush == 0 && (load||alui||auipc||alur||lui||jalr||jal);
    wire [31:0] r1;
    wire [31:0] r2;

    registers regs (
        .clk(clk), .rst(rst), .hlt(hlt),
        .rs1(rs1), .r1(r1), .rs2(rs2), .r2(r2),
        .rd(rd), .wdata(result), .write(write)
    );
    
    alu alu (
        .arg0((jal || branch) ? inpc : r1),
        .arg1u(alur ? r2 : immu),
        .arg1s(alur ? r2 : imms),
        .funct3((alui || alur) ? funct3 : 3'b000),
        .funct7(funct7),
        .alur(alur),
        .result(alu_result)
    );

    cmp cmp (
        .arg0(r1), .arg1(r2), .funct3(funct3),
        .result(branch_taken)
    );

    mem mem (
        .hlt(flush != 0), .load(load), .store(store),
        .r1(r1), .r2(r2), .funct3(funct3),
        .imms(imms),
        .mem_valid(mem_valid),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .result(mem_result)
    );

    system sys (
        .clk(clk), .hlt(hlt), .rst(rst)
    );

    assign newpc = alu_result;
    assign override = (flush == 0) & ((branch & branch_taken) | jal | jalr);
    assign fault = (flush == 0) & invalid;

    always @ (posedge clk) if(rst) begin
        flush <= 2;
    end else if(!hlt) begin
        flush <= (flush == 0) ? (override ? 2 : flush) : flush - 1;
    end
endmodule

module registers (
    clk, rst, hlt,
    rs1, r1, rs2, r2,
    rd, wdata, write,
);
    input clk, rst, hlt;
    input [4:0] rs1;
    output [31:0] r1;
    input [4:0] rs2;
    output [31:0] r2;
    input [4:0] rd;
    input [31:0] wdata;
    input write;
    
    reg [31:0] regs[0:31];

    assign r1 = rs1 ? regs[rs1] : 32'h00000000;
    assign r2 = rs2 ? regs[rs2] : 32'h00000000;
    integer i;
    initial for(i = 0; i < 32; i = i + 1) regs[i] = 32'h00000000;
    always @ (posedge clk) if(write) regs[rd] <= wdata;
endmodule

module cmp (arg0, arg1, funct3, result);
    input [31:0] arg0;
    input [31:0] arg1;
    input [2:0] funct3;
    output result;
    wire eq = arg0 == arg1;
    wire ne = arg0 != arg1;
    wire gtu = arg0 > arg1;
    wire ltu = arg0 < arg1;
    wire gt = $signed(arg0) > $signed(arg1);
    wire lt = $signed(arg0) < $signed(arg1);
    wire ge = eq || gt;
    wire geu = eq || gtu;
    assign result = funct3 == 0 ? eq
                  : funct3 == 1 ? ne
                  : funct3 == 4 ? lt
                  : funct3 == 5 ? ge
                  : funct3 == 6 ? ltu
                  : funct3 == 7 ? geu
                  : 0 ;
endmodule

module alu (arg0, arg1u, arg1s, funct3, funct7, alur, result);
    input [31:0] arg0;
    input [31:0] arg1u;
    input [31:0] arg1s;
    input [2:0] funct3;
    input [6:0] funct7;
    input alur;
    output [31:0] result;

    wire do_sub = alur && funct7[5];
    wire do_sra = funct7[5];

    assign result = (funct3 == 0) ? (do_sub ? (arg0 - arg1s) : (arg0 + arg1s))
                  : (funct3 == 1) ? (arg0 < arg1u[4:0])
                  : (funct3 == 2) ? ($signed(arg0) < $signed(arg1s))
                  : (funct3 == 3) ? (arg0 < arg1u)
                  : (funct3 == 4) ? (arg0 ^ arg1s)
                  : (funct3 == 5) ? (do_sra ? (arg0 >>> arg1u[4:0]) :  (arg0 >> arg1u[4:0]))
                  : (funct3 == 6) ? (arg0 | arg1s)
                  : (funct3 == 7) ? (arg0 & arg1s) : 0;
endmodule

module mem (
    hlt, load, store,
    r1, r2, funct3,
    imms,
    mem_valid, 
    mem_addr,mem_rdata,
    mem_wdata, mem_wstrb,
    result
);
    input hlt;
    input load, store;
    input [31:0] r1;
    input [31:0] r2;
    input [2:0] funct3;
    input [31:0] imms;

    output mem_valid;
    output [31:0] mem_addr;
    input [31:0] mem_rdata;
    output [31:0] mem_wdata;
    output [3:0] mem_wstrb;
    
    output [31:0] result;
    
    assign mem_valid = !hlt & (load | store);
    assign mem_addr = r1 + imms;
    assign mem_wdata = r2;
    assign mem_wstrb = (!hlt & store) ? 4'b1111 : 4'b0000;
    assign result = mem_rdata;
endmodule

module system (
    clk, rst, hlt,
    system, 
    rs1, r1, uimm,
);
    input clk, rst, hlt;
    input system;
    input [4:0] rs1;
    input [31:0] r1;
    input [31:0] uimm;
    
endmodule 
