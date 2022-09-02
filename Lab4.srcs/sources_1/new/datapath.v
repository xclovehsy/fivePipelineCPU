`timescale 1ns / 1ps


module datapath(
    input clk,          
    input rst,          
    input [31:0] instr,
    input [31:0] readdata,
    
    //---------------------------    
    output [31:0] aluout,    
    output [31:0] pc,           
    output [31:0] writedata,     
    output [31:0] memwrite
    );

    // 数据信号----------------------
    wire [31:0] PC_, PC_new, PCF, InstrD;
    wire [31:0] PCPlus4F, PCPlus4D, PCPlus4E;               
    wire [31:0] Rd1D, Rd2D, Rd1E, Rd2E;
    wire [4:0] RtE, RdE, RsE, RsD, RtD, RdD;
    wire [31:0] SignImmD, SignImmE;
    wire [31:0] SrcAE, SrcBE, WriteDataE,WriteDataM;
    wire [4:0] WriteRegE, WriteRegM, WriteRegW;
    wire [31:0] PCBranchE, PCBranchM, PCBranchD;
    wire [31:0] ALUOutE, ALUOutM, ALUOutW;
    wire ZeroE, ZeroM;
    wire [31:0] ReadDataW, ResultW;
    //-------------------------------

    // 控制信号-----------------------
    wire RegWriteD, RegWriteE, RegWriteM, RegWriteW;
    wire MemtoRegD, MemtoRegE, MemtoRegM, MemtoRegW;
    wire MemWriteD, MemWriteE, MemWriteM;
    wire BranchD, BranchE, BranchM;
    wire [2:0] ALUControlD, ALUControlE;
    wire ALUSrcD, ALUSrcE;
    wire RegDstD, RegDstE;
    wire PCSrcM, PCSrcD;
    wire JumpD;
    //-------------------

    // 竞争处理信号------------------
    wire [1:0]ForwardAE, ForwardBE;
    wire StallF, StallD, FlushE;
    wire ForwardAD, ForwardBD;
    //----------------------------------

    
    //信号连接-----------------------
    assign aluout = ALUOutM;
    assign pc = PCF;
    assign writedata = WriteDataM;
    assign memwrite = MemWriteM;

    assign RsD = InstrD[25:21];
    assign RtD = InstrD[20:16];
    assign RdD = InstrD[15:11];
    //--------------------------


    
    // 竞争冒险处理
    hazard ha(
        .RsE(RsE),
        .RtE(RtE),
        .RsD(RsD),
        .RtD(RtD),
        .WriteRegM(WriteRegM),
        .WriteRegW(WriteRegW),
        .WriteRegE(WriteRegE), 
        .RegWriteM(RegWriteM), 
        .RegWriteW(RegWriteW),
        .RegWriteE(RegWriteE),
        .MemtoRegE(MemtoRegE), 
        .MemtoRegM(MemtoRegM),
        .MemtoRegW(MemtoRegW), 
        .BranchD(BranchD), 
        
        //----------
        .ForwardAE(ForwardAE), 
        .ForwardBE(ForwardBE),
        .ForwardAD(ForwardAD), 
        .ForwardBD(ForwardBD),  
        .StallF(StallF), 
        .StallD(StallD), 
        .FlushE(FlushE)
    );



    // Fetch阶段
    mux2 #(32) pc_mux1(.a(PCPlus4F), .b(PCBranchD), .f(PCSrcD), .c(PC_));
    mux2 #(32) pc_mux2(.a(PC_), .b({PCPlus4F[31:28], InstrD[25:0], 2'b00}), .f(JumpD), .c(PC_new));
    
    pc p(
        .clk(clk), 
        .rst(rst),
        .clr(1'b0),
        .en(~StallF),
        .newpc(PC_new), 
        .pc(PCF)
    );
    
    assign PCPlus4F = PCF + 32'h4;

    // 32+32
    flopenrc #(200) flop_D(
        .clk(clk), 
        .rst(rst), 
        .en(~StallD), 
        .clear(PCSrcD),
        .d({instr, PCPlus4F}), 
        .q({InstrD, PCPlus4D})
    ); 




    // Decode阶段
    // 控制竞争
    wire [31:0]t_rd1, t_rd2;
    mux2 rd1_mux(.a(Rd1D), .b(ALUOutM), .f(ForwardAD), .c(t_rd1));
    mux2 rd2_mux(.a(Rd2D), .b(ALUOutM), .f(ForwardBD), .c(t_rd2));
    assign PCSrcD = BranchD & (t_rd1 == t_rd2);
    
    controller c(
		.inst(InstrD),
		//------------------
		.regwrite(RegWriteD),
		.memtoreg(MemtoRegD),
		.memwrite(MemWriteD),
		.branch(BranchD),
		.alucontrol(ALUControlD),
		.alusrc(ALUSrcD),
		.regdst(RegDstD),
        .jump(JumpD)
	);

    regfile rf( 
        .clk(clk),
        .we3(RegWriteW), 
        .ra1(InstrD[25:21]), 
        .ra2(InstrD[20:16]), 
        .wa3(WriteRegW), 
        .wd3(ResultW),
        .rd1(Rd1D), 
        .rd2(Rd2D)
    );


    assign SignImmD = {{16{InstrD[15]}}, InstrD[15:0]};
    adder branch_add(.a({SignImmD[29:0], 2'b00}), .b(PCPlus4D), .y(PCBranchD));

    // (1+1+1+1+1+1+3)+(32+32+5+5+5+32) = 120
    flopenrc #(200) flop_E(
        .clk(clk), 
        .en(1'b1), 
        .clear(FlushE), 
        .rst(rst), 
        .d({RegWriteD,MemtoRegD,MemWriteD,BranchD,ALUControlD,ALUSrcD,RegDstD,Rd1D, Rd2D, InstrD[25:11], SignImmD}), 
        .q({RegWriteE,MemtoRegE,MemWriteE,BranchE,ALUControlE,ALUSrcE,RegDstE,Rd1E, Rd2E, RsE, RtE, RdE, SignImmE})    
    );



    // Execute阶段
    alu #(32) alu(.A(SrcAE), .B(SrcBE), .F(ALUControlE), .result(ALUOutE));
    mux2 #(32) alu_mux(.a(WriteDataE), .b(SignImmE), .f(ALUSrcE), .c(SrcBE));
    mux2 #(5) reg_mux(.a(RtE), .b(RdE), .f(RegDstE), .c(WriteRegE));
    // assign ZeroE = ALUOutE == 32'b0;

    //数据前推
    mux3 SrcAE_mux(.a(Rd1E), .b(ResultW), .c(ALUOutM), .f(ForwardAE), .y(SrcAE));
    mux3 SrcBE_mux(.a(Rd2E), .b(ResultW), .c(ALUOutM), .f(ForwardBE), .y(WriteDataE));

    // (1+1+1)+(32+32+5) = 72
    flopenrc #(200) flop_M(
        .clk(clk), 
        .rst(rst),
        .en(1'b1), 
        .clear(1'b0),
        .d({RegWriteE,MemtoRegE,MemWriteE, ALUOutE, WriteDataE,WriteRegE}), 
        .q({RegWriteM,MemtoRegM,MemWriteM, ALUOutM, WriteDataM, WriteRegM})
    );



    // Memory阶段
    // assign PCSrcM = BranchM & ZeroM;
    // assign PCSrcM = 1'b0;

    // (1+1)+(32+32+5) = 71
    flopenrc #(200) flop_W(
        .clk(clk), 
        .rst(rst), 
        .clear(1'b0),
        .en(1'b1),
        .d({RegWriteM,MemtoRegM,ALUOutM, readdata, WriteRegM}), 
        .q({RegWriteW,MemtoRegW,ALUOutW, ReadDataW, WriteRegW})
    );

    // Write Back阶段
    mux2 #(32) result_mux(.a(ALUOutW), .b(ReadDataW), .f(MemtoRegW), .c(ResultW));

    
endmodule