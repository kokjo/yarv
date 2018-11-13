module execute (
    // control signals
    input clk, input rstn, input hlt,
    // pipeline input 
    // decoded immediates
    input [31:0] imms, input [31:0] immu,
    // instruction parts,
    input [6:0] opcode, input [4:0] rd, input [2:0] funct3,
    input [4:0] rs1, input [4:0] rs2, input [6:0] funct7,
    // individual opcodes
    input load, input fence, input alui, input auipc,
    input store, input alur, input lui, input branch,
    input jalr, input jal, input system,
    // instruction decode fail
    input invalid, input unknown,
    // pc for next stage
    input [31:0] inpc,
    // branch control signals
    output override, output [31:0] newpc,
    // fault control signal
    output fault,
    // load/store signals
    output mem_valid, input mem_ready,
    output [31:0] mem_addr, input [31:0] mem_rdata,
    output [31:0] mem_wdata, output [3:0] mem_wstrb,
);
    wire [31:0] alu_result;
    wire [31:0] mem_result;
    wire branch_taken;

    reg [1:0] flush;

    wire [31:0] result = auipc ? inpc + imms
                       : lui ? imms 
                       : (alui || alur) ? alu_result
                       : (jal || jalr) ? inpc + 4 
                       : load ? mem_result
                       : system ? sys_result
                       : 32'h00000000;


    wire write = !hlt && flush == 0
               && (load||alui||auipc||alur||lui||jalr||jal||(system && sys_write));
    wire [31:0] r1;
    wire [31:0] r2;

    registers regs (
        .clk(clk), .rstn(rstn), .hlt(hlt),
        .rs1(rs1), .r1(r1), .rs2(rs2), .r2(r2),
        .rd(rd), .wdata(result), .write(write)
    );
    
    alu alu (
        .arg0(r1),
        .arg1u(alur ? r2 : immu),
        .arg1s(alur ? r2 : imms),
        .funct3(funct3),
        .funct7(funct7),
        .alur(alur),
        .result(alu_result)
    );

    cmp cmp (
        .arg0(r1), .arg1(r2), .funct3(funct3),
        .result(branch_taken)
    );

    mem mem (
        .clk(clk), .rstn(rstn), .hlt(hlt),
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
        .clk(clk), .hlt(hlt || flush != 0), .rstn(rstn),
        .system(system), .exception(1'b0), .cause(32'h00000000),
        .pc(inpc), .rd(rd), .funct3(funct3), .rs1(rs1), .r1(r1), .immu(immu),
        .result(sys_result),
        .write(sys_write),
        .override(sys_override),
        .newpc(sys_newpc)
    );

    wire [31:0] branch_newpc = (jalr ? r1 : inpc) + imms;

    assign newpc = sys_override ? sys_newpc : branch_newpc;
    assign override = (flush == 0) & ((branch & branch_taken) | jal | jalr | sys_override);
    assign fault = (flush == 0) & invalid;

    always @ (posedge clk) if(!rstn) begin
        flush <= 2;
    end else if(!hlt) begin
        flush <= (flush == 0) ? (override ? 2 : flush) : flush - 1;
    end
endmodule

module registers (
    input clk, input rstn, input hlt,
    input [4:0] rs1, output [31:0] r1, input [4:0] rs2, output [31:0] r2,
    input [4:0] rd, input [31:0] wdata, input write
);
    reg [31:0] regs[0:31];

    assign r1 = rs1 ? regs[rs1] : 32'h00000000;
    assign r2 = rs2 ? regs[rs2] : 32'h00000000;
    integer i;
    initial for(i = 0; i < 32; i = i + 1) regs[i] = 32'h00000000;
    always @ (posedge clk) if(write) regs[rd] <= wdata;
endmodule

module cmp (
    input [31:0] arg0, input [31:0] arg1, input [2:0] funct3, output result
);
    wire eq = arg0 == arg1;
    wire ne = arg0 != arg1;
    wire gtu = arg0 > arg1;
    wire ltu = arg0 < arg1;
    wire gt = $signed(arg0) > $signed(arg1);
    wire lt = $signed(arg0) < $signed(arg1);
    assign result = funct3 == 0 ? eq
                  : funct3 == 1 ? ne
                  : funct3 == 4 ? lt
                  : funct3 == 5 ? (eq || gt)
                  : funct3 == 6 ? ltu
                  : funct3 == 7 ? (eq || gtu)
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
                  : (funct3 == 1) ? (arg0 << arg1u[4:0])
                  : (funct3 == 2) ? ($signed(arg0) < $signed(arg1s))
                  : (funct3 == 3) ? (arg0 < arg1u)
                  : (funct3 == 4) ? (arg0 ^ arg1s)
                  : (funct3 == 5) ? (do_sra ? (arg0 >>> arg1u[4:0]) : (arg0 >> arg1u[4:0]))
                  : (funct3 == 6) ? (arg0 | arg1s)
                  : (funct3 == 7) ? (arg0 & arg1s)
                  : 32'h00000000;
endmodule

module mem (
    input clk, input rstn, input hlt,
    input [1:0] flush,
    input load, input store,
    input [31:0] r1, input [31:0] r2, input [2:0] funct3,
    input [31:0] imms,
    output mem_valid, input mem_ready,
    output [31:0] mem_addr, input [31:0] mem_rdata,
    output [31:0] mem_wdata, output [3:0] mem_wstrb,
    output [31:0] result
);
    reg mem_done;
    reg [31:0] rdata_latch;
    wire [31:0] rdata = mem_done ? rdata_latch : mem_rdata;
    
    wire byte_access = funct3[1:0] == 2'b00;
    wire word_access = funct3[1:0] == 2'b01;
    wire dword_access = funct3[1:0] == 2'b10;

    wire signextend = !funct3[2];

    wire [31:0] mem_addr_unaligned = r1 + imms;
    wire [1:0] byte_off = mem_addr_unaligned[1:0];

    wire [3:0] wstrb = byte_access ? (4'b0001 << byte_off)
               : word_access ? (4'b0011 << 2*byte_off[1])
               : 4'b1111;

    wire [31:0] wdata = byte_access ? (r2 << 8*byte_off)
                      : word_access ? (r2 << 16*byte_off[1])
                      : r2;

    wire [7:0] byte = rdata >> 8*byte_off;
    wire [15:0] word = rdata >> 16*byte_off[1];
    wire [31:0] byte_result = {{24{byte[7] && signextend}}, byte};
    wire [31:0] word_result = {{16{word[15] && signextend}}, word};

    assign mem_valid = (flush == 0) & (load | store) & !mem_done;
    assign mem_addr = mem_addr_unaligned & ~3;
    assign mem_wdata = wdata;
    assign mem_wstrb = ((flush == 0) & store & !mem_done) ? wstrb : 4'b0000;
    assign result = byte_access ? byte_result
                  : word_access ? word_result
                  : rdata;

    always @ (posedge clk) if(!rstn) begin
        mem_done <= 0;
        rdata_latch <= 0;
    end else begin
        if(hlt && (load || store) && !mem_done)begin
            mem_done <= 0; 
        end
        if(mem_ready) begin
            mem_done <= 1;
            rdata_latch <= mem_rdata;
        end
        if(!hlt) mem_done <= 0;
    end
endmodule

module system (
    input clk, input rstn, input hlt,
    input system, input exception, input [31:0] cause,
    input [31:0] pc,
    input [4:0] rd, input [2:0] funct3, input [4:0] rs1, input [31:0] r1, input [31:0] immu,
    output [31:0] result, output write,
    output [31:0] newpc, output override
);

    localparam PRIV = 3'b000;
    localparam CSRRW = 3'b001;
    localparam CSRRS = 3'b010;
    localparam CSRRC = 3'b011;
    localparam CSRRWI = 3'b101;
    localparam CSRRSI = 3'b110;
    localparam CSRRCI = 3'b111;

    wire [11:0] csr_addr = immu[11:0];
    wire csr_read = system && rd != 0 && (
        funct3 == CSRRW || funct3 == CSRRS || funct3 == CSRRC ||
        funct3 == CSRRWI || funct3 == CSRRSI || funct3 == CSRRSI);
    wire [31:0] csr_rdata;
    wire csr_write = system && (
        funct3 == CSRRW || ((funct3 == CSRRS || funct3 == CSRRC) && rs1 != 0) ||
        funct3 == CSRRWI || ((funct3 == CSRRSI || funct3 == CSRRCI) && rs1 != 0));
    wire [31:0] csr_wdata = funct3 == CSRRW ? r1
                          : funct3 == CSRRS ? (csr_rdata | r1)
                          : funct3 == CSRRC ? (csr_rdata & ~r1)
                          : funct3 == CSRRWI ? rs1
                          : funct3 == CSRRSI ? (csr_rdata | rs1)
                          : funct3 == CSRRCI ? (csr_rdata & ~rs1)
                          : 32'hxxxxxxxx;
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
        .clk(clk), .rstn(rstn), .hlt(hlt),
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
    input clk, input rstn, input hlt,
    // CSR read/write interface
    input [11:0] csr,
    input read, output [31:0] rdata,
    input write, input [31:0] wdata,
    // CSR values
    output reg [31:0] mscratch,
    output reg [31:0] mepc, input mepc_write, input [31:0] mepc_wdata,
    output reg [31:0] mcause, 
    output reg [31:0] mtvec
);

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

    localparam CYCLE      = 12'hc00;
    localparam TIME       = 12'hc01;
    localparam INSTRET    = 12'hc02;

    localparam CYCLEH     = 12'hc80;
    localparam TIMEH      = 12'hc81;
    localparam INSTRETH   = 12'hc82;

    parameter MISA_VALUE  = 32'h00000000;

    reg [63:0] cycle;
    reg [63:0] instret;
    
    assign rdata = (csr == MISA) ? MISA_VALUE
                 : (csr == MSCRATCH) ? mscratch
                 : (csr == MEPC) ? mepc
                 : (csr == MCAUSE) ? mcause
                 : (csr == MTVEC) ? mtvec
                 : (csr == CYCLE) ? cycle[31:0]
                 : (csr == INSTRET) ? instret[31:0]
                 : (csr == CYCLEH) ? cycle[63:32]
                 : (csr == INSTRET) ? instret[63:32]
                 : 32'hxxxxxxxx;

    always @ (posedge clk) if(!rstn) begin
        mscratch <= 0;
        mcause <= 0;
        mepc <= 0;
        mtvec <= 0;
    end else if(!hlt) begin
        if(write) case(csr)
            MSCRATCH: mscratch <= wdata;
            MEPC: mepc <= wdata;
            MCAUSE: mcause <= wdata;
            MTVEC: mtvec <= wdata;
        endcase
        if(mepc_write) mepc <= mepc_wdata;
    end

    always @ (posedge clk) if(!rstn) begin
        cycle <= 64'd0;
        instret <= 64'd0;
    end else begin
        cycle <= cycle + 1;
        if(!hlt) instret <= instret + 1;
    end
endmodule
