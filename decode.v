module decode (
    // control signals
    input clk, input rstn, input hlt,
    // pipeline input
    input [31:0] instruction, input [31:0] inpc,
    // pipeline output,
    // decoded immediates
    output reg [31:0] imms, output reg [31:0] immu,
    // instruction parts,
    output reg [6:0] opcode, output reg [4:0] rd, output reg [2:0] funct3,
    output reg [4:0] rs1, output reg [4:0] rs2, output reg [6:0] funct7,
    // individual opcodes
    output reg load, output reg fence, output reg alui, output reg auipc,
    output reg store, output reg alur, output reg lui, output reg branch,
    output reg jalr, output reg jal, output reg system,
    // fault signals
    output reg invalid, output reg unknown,
    // pc for next stage
    output reg [31:0] outpc
);
    wire load_w, fence_w, alui_w, auipc_w;
    wire store_w, alur_w, lui_w, branch_w;
    wire jalr_w, jal_w, system_w;
    wire invalid_w, unknown_w;

    wire r, i, s, b, u, j;

    opcode_decode opcode_decode0 (
        .opcode(instruction[6:0]),
        .r(r), .i(i), .s(s), .b(b), .u(u), .j(j),
        .load(load_w), .fence(fence_w), .alui(alui_w), .auipc(auipc_w),
        .store(store_w), .alur(alur_w), .lui(lui_w), .branch(branch_w),
        .jalr(jalr_w), .jal(jal_w), .system(system_w),
        .invalid(invalid_w), .unknown(unknown_w)
    );
    
    wire [31:0] inst = instruction;

    wire [11:0] immIw = i ? {inst[31:20]} : 12'd0;
    wire [31:0] immIu = {20'd0, immIw};
    wire [31:0] immIs = {{20{immIw[11]}}, immIw};
    wire [11:0] immSw = s ? {inst[31:25],inst[11:7]} : 12'd0;
    wire [31:0] immSu = {20'd0, immSw};
    wire [31:0] immSs = {{20{immSw[11]}}, immSw};
    wire [12:0] immBw = b ? {inst[31],inst[7],inst[30:25],inst[11:8],1'b0} : 13'd0;
    wire [31:0] immBu = {19'd0, immBw};
    wire [31:0] immBs = {{19{immBw[11]}}, immBw};
    wire [31:0] immUw = u ? {inst[31:12], 12'd0} : 32'd0;
    wire [31:0] immUu = immUw;
    wire [31:0] immUs = immUw;
    wire [20:0] immJw = j ? {inst[31],inst[19:12],inst[20],inst[30:21],1'b0}: 21'd0;
    wire [31:0] immJu = {11'd0, immJw};
    wire [31:0] immJs = {{11{immJw[20]}}, immJw};

    always @ (posedge clk) if(!rstn) begin
        imms <= 32'd0; immu <= 32'd0;
        opcode <= 7'd0; rd <= 5'd0; funct3 <= 3'd0;
        rs1 <= 5'd0; rs2 <= 5'd0; funct7 <= 7'd0;
        load <= 1'b0; fence <= 1'b0; alui <= 1'b0; auipc <= 1'b0;
        store <= 1'b0; alur <= 1'b0; lui <= 1'b0; branch <= 1'b0;
        jalr <= 1'b0; jal <= 1'b0; system <= 1'b0;
        invalid <= 1'b0; unknown <= 1'b0;
        outpc <= 32'd0;
    end else if(!hlt) begin
        immu <= immIu | immSu | immBu | immUu | immJu;
        imms <= immIs | immSs | immBs | immUs | immJs;
        opcode <= instruction[6:0];
        rd <= instruction[11:7];
        funct3 <= instruction[14:12];
        rs1 <= instruction[19:15];
        rs2 <= instruction[24:20];
        funct7 <= instruction[31:25];
        load <= load_w; fence <= fence_w; alui <= alui_w; auipc <= auipc_w;
        store <= store_w; alur <= alur_w; lui <= lui_w; branch <= branch_w;
        jalr <= jalr_w; jal <= jal_w; system <= system_w;
        invalid <= invalid_w; unknown <= unknown_w;
        outpc <= inpc;
    end
endmodule

module opcode_decode (
    // instruction input
    opcode,
    // immediate type
    r, i, s, b, u, j,
    // opcodes
    load, fence, alui, auipc,
    store, alur, lui, branch,
    jalr, jal, system,
    // instruction decode fail
    invalid, unknown
);
    input [6:0] opcode;
    output r, i, s, b, u, j;
    output load, fence, alui, auipc;
    output store, alur, lui, branch;
    output jalr, jal, system; 
    output invalid, unknown;
   
    assign r = alur; 
    assign i = jalr | load | alui | fence | system;
    assign s = store;
    assign b = branch;
    assign u = lui | auipc;
    assign j = jal;

    assign load   = opcode[6:2] == 5'b00000;
    assign fence  = opcode[6:2] == 5'b00011;
    assign alui   = opcode[6:2] == 5'b00100;
    assign auipc  = opcode[6:2] == 5'b00101;
    assign store  = opcode[6:2] == 5'b01000;
    assign alur   = opcode[6:2] == 5'b01100;
    assign lui    = opcode[6:2] == 5'b01101;
    assign branch = opcode[6:2] == 5'b11000;
    assign jalr   = opcode[6:2] == 5'b11001;
    assign jal    = opcode[6:2] == 5'b11011;
    assign system = opcode[6:2] == 5'b11100;
        
    assign unknown = !( load | fence | alui | auipc
                      | store | alur | lui | branch
                      | jalr | jal | system );
        
    assign invalid = !(opcode[0] | opcode[1]) | unknown;
endmodule
