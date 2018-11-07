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
    mem_ready,
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
    input mem_ready;
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
                       : system ? sys_result
                       : 32'h00000000;

    reg [1:0] flush;

    wire write = !hlt && flush == 0
               && (load||alui||auipc||alur||lui||jalr||jal||(system && sys_write));
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
        .clk(clk), .rst(rst), .hlt(hlt),
        .flush(flush),
        .load(load), .store(store),
        .r1(r1), .r2(r2), .funct3(funct3),
        .imms(imms),
        .mem_valid(mem_valid),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .result(mem_result)
    );

    wire [31:0] sys_result;
    wire sys_write;
    wire sys_override;
    wire [31:0] sys_newpc;

    system sys (
        .clk(clk), .hlt(hlt || flush != 0), .rst(rst),
        .system(system), .exception(1'b0), .cause(32'h00000000),
        .pc(inpc), .rd(rd), .funct3(funct3), .rs1(rs1), .r1(r1), .immu(immu),
        .result(sys_result),
        .write(sys_write),
        .override(sys_override),
        .newpc(sys_newpc)
    );

    assign newpc = sys_override ? sys_newpc : alu_result;
    assign override = (flush == 0) & ((branch & branch_taken) | jal | jalr | sys_override);
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
    clk, rst, hlt,
    flush,
    load, store,
    r1, r2, funct3,
    imms,
    mem_valid, mem_ready,
    mem_addr,mem_rdata,
    mem_wdata, mem_wstrb,
    result
);
    input clk;
    input hlt;
    input rst;
    input [1:0] flush;

    input load, store;
    input [31:0] r1;
    input [31:0] r2;
    input [2:0] funct3;
    input [31:0] imms;

    output mem_valid;
    input mem_ready;
    output [31:0] mem_addr;
    input [31:0] mem_rdata;
    output [31:0] mem_wdata;
    output [3:0] mem_wstrb;
    
    output [31:0] result;

    reg mem_done;
    
    assign mem_valid = (flush == 0) & (load | store) & !mem_done;
    assign mem_addr = r1 + imms;
    assign mem_wdata = r2;
    assign mem_wstrb = ((flush == 0) & store & !mem_done) ? 4'b1111 : 4'b0000;
    assign result = mem_rdata;

    always @ (posedge clk) begin
        if(hlt && (load || store) && !mem_done)begin
            mem_done <= 0; 
        end
        if(mem_ready) mem_done <= 1;
        if(!hlt) mem_done <= 0;
    end
endmodule

module system (
    clk, rst, hlt,
    system, exception, cause,
    pc, rd, funct3, rs1, r1, immu,
    result, write,
    newpc, override
);
    input clk, rst, hlt;
    input system;
    input exception;
    input [31:0] cause;
    input [31:0] pc;
    input [4:0] rd;
    input [2:0] funct3;
    input [4:0] rs1;
    input [31:0] r1;
    input [31:0] immu;
    output [31:0] result; 
    output write;
    output [31:0] newpc;
    output override;

    wire [11:0] csr_addr = immu[11:0];
    wire csr_read = system && funct3 == 3'b001 && rd != 0;
    wire [31:0] csr_rdata;
    wire csr_write = system && funct3 == 3'b001;
    wire [31:0] csr_wdata = r1;
    wire [31:0] mepc;
    wire mepc_write;
    wire [31:0] mepc_wdata;
    wire [31:0] mtvec;

    assign result = csr_rdata;
    assign write = system && funct3 == 3'b001;

    assign mret   = system && funct3 == 3'b000 && immu[11:0] == 12'b001100000010;
    assign ecall  = system && funct3 == 3'b000 && immu[11:0] == 12'b000000000000;
    assign ebreak = system && funct3 == 3'b000 && immu[11:0] == 12'b000000000001;

    assign exc = exception || ecall || ebreak;

    assign override = (exc || mret);
    assign newpc = exc ? mtvec
                 : mret ? mepc
                 : 32'h00000000 ;

    assign mepc_write = exc;
    assign mepc_wdata = pc;

    csr csr (
        .clk(clk), .rst(rst), .hlt(hlt),
        .csr(csr_addr),
        .read(csr_read),
        .rdata(csr_rdata),
        .write(csr_write),
        .wdata(csr_wdata),
        .mepc(mepc), .mepc_write(mepc_write), .mepc_wdata(mepc_wdata),
        .mtvec(mtvec)
    );

endmodule 

module csr (
    clk, rst, hlt,
    // CSR read/write interface
    csr,
    read, rdata,
    write, wdata,
    // CSR values
    mscratch,
    mepc, mepc_write, mepc_wdata,
    mcause,
    mtvec
);
    input clk, rst, hlt;
    input [11:0] csr;
    input read;
    output [31:0] rdata;
    input write;
    output [31:0] wdata;

    output reg [31:0] mscratch;
    output reg [31:0] mepc;
    input mepc_write;
    input [31:0] mepc_wdata;
    output reg [31:0] mcause;
    output [31:0] mtvec;

    localparam MSTATUS    = 12'h300;
    localparam MISA       = 12'h301;
    localparam MEDELEG    = 12'h302;
    localparam MIDELEG    = 12'h303;
    localparam MIE        = 12'h304;
    localparam MTVEC      = 12'h305;
    localparam MCOUNTEREN = 12'h306;

    localparam MSCRATCH   = 12'h340;
    localparam MEPC       = 12'h341;
    localparam MCAUSE     = 12'h342;
    localparam MTVAL      = 12'h343;
    localparam MTIP       = 12'h344;

    parameter MISA_VALUE  = 32'h00000000;
    parameter MTVEC_VALUE = 32'h00050004;

    assign mtvec = MTVEC_VALUE;
    
    assign rdata = (csr == MISA) ? MISA_VALUE
                 : (csr == MSCRATCH) ? mscratch
                 : (csr == MEPC) ? mepc
                 : (csr == MCAUSE) ? mcause
                 : 32'h00000000;

    always @ (posedge clk) if(rst) begin
        mscratch <= 0;
        mcause <= 0;
        mepc <= 0;
    end else if(!hlt) begin
        if(write) case(csr)
            MSCRATCH: mscratch <= wdata;
            MEPC: mepc <= wdata;
            MCAUSE: mcause <= wdata;
        endcase
        if(mepc_write) mepc <= mepc_wdata;
    end
endmodule
