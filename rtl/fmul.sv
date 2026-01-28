`timescale 1ns / 1ps

module fmul #(
    //parameter DATA_WIDTH = 32,
    parameter EXP = 8,
    parameter MANT = 23,
    parameter BIAS = 127  
)(
    input [EXP + MANT:0] a_i,
    input [EXP + MANT:0] b_i,
    output wire [EXP + MANT:0] c_o
    );
    localparam DATA_WIDTH = 1 + EXP + MANT;
    wire sign_c;
    wire [EXP - 1:0] exp_a;
    wire [EXP - 1:0] exp_b;
    reg [EXP - 1:0] exp_c;
    reg [2*MANT+1:0] pom_mant; //47 do 0
    wire [MANT - 1:0] mant_a;
    wire [MANT - 1:0] mant_b;
    reg [MANT - 1:0] mant_c;
    
    assign sign_c = a_i[DATA_WIDTH - 1] ^ b_i[DATA_WIDTH - 1]; //ovo je moglo i u always-u da se ne bi stalno pisalo assign itd...
    assign exp_a = a_i[DATA_WIDTH - 2:MANT];
    assign exp_b = b_i[DATA_WIDTH - 2:MANT];
    
    assign mant_a = a_i[MANT - 1:0];
    assign mant_b = b_i[MANT - 1:0];
    
    assign c_o = (a_i == 0 || b_i == 0) ? 'h0 : {sign_c, exp_c, mant_c};
    
    always @(*)begin
        exp_c = exp_a + exp_b - BIAS;
        pom_mant = {1'b1, mant_a} * {1'b1, mant_b};
        if (pom_mant[2*MANT+1] == 1'b1) begin //10 xx normalizacija
            pom_mant = pom_mant >> 1;     //sad je pom sigurno oblika: 01 46bita
            exp_c = exp_c + 1;
        end
        if (pom_mant[MANT - 1] == 1'b0)begin  //01 xx
            mant_c = pom_mant[2*MANT - 1:MANT];
        end else if (pom_mant[MANT - 1] == 1'b1)begin //odbaceni bit 1?
            if (|pom_mant[MANT - 2:0]) begin  //bar jedna jedinica          IZMENJENO
                mant_c = pom_mant[2*MANT - 1:MANT] + 1; //na vise   //round IZMENJEN
                
                if (mant_c[MANT - 1] == 1'b1) begin   // normalizacija 
                    mant_c = mant_c >> 1;
                    exp_c = exp_c + 1;
                end
                
            end else if (~|pom_mant[MANT - 2:0]) begin //nema nijedne jedinice
                if (pom_mant[MANT] == 1'b1) begin //poslednji bit 1?
                    mant_c = pom_mant[2*MANT - 1:MANT] + 1; //na vise  IZMENJENO                    
                    if (mant_c[MANT - 1] == 1'b1) begin   //normalizacija 
                        mant_c = mant_c >> 1;
                        exp_c = exp_c + 1;
                    end
                    
                end else if (pom_mant[MANT] == 1'b0) begin //poslednji bit 0?
                    mant_c = pom_mant[2*MANT - 1:MANT];
                end
           end
         end
     end

endmodule
