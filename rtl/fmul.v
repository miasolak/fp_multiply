`timescale 1ns / 1ps

module fmul #(
    parameter DATA_WIDTH = 32,
    parameter EXP = 8,
    parameter MANT = 23,
    parameter BIAS = 127  
)(
    input [DATA_WIDTH - 1:0] a_i,
    input [DATA_WIDTH - 1:0] b_i,
    output wire [DATA_WIDTH - 1:0] c_o
    );
    
    wire sign_c;
    reg [EXP - 1:0] exp_c;
    reg [2*MANT+1:0] pom_mant; //47 do 0
    reg [MANT - 1:0] mant_c;
  //  wire [BIAS - 1:0] bias;
    assign sign_c = a_i[DATA_WIDTH - 1] ^ b_i[DATA_WIDTH - 1]; //ovo je moglo i u always-u da se ne bi stalno pisalo assign itd...
//    always @(*)begin
//      sign_c = a_i[31] ^ b_i[31];
//    end
  //  assign bias = 127;
    assign c_o = (a_i == 0 || b_i == 0) ? 'h0 : {sign_c, exp_c, mant_c};
    
    always @(*)begin
        exp_c = a_i[DATA_WIDTH - 2:MANT] + b_i[DATA_WIDTH - 2:MANT] - BIAS;
        pom_mant = {1'b1, a_i[MANT - 1:0]} * {1'b1, b_i[MANT - 1:0]};
        if (pom_mant[2*MANT+1] == 1'b1) begin //10 xx normalizacija
            pom_mant = pom_mant >> 1;     //sad je pom sigurno oblika: 01 46bita
            exp_c = exp_c + 1;
        end
        if (pom_mant[MANT - 1] == 1'b0)begin  //01 xx
            mant_c = pom_mant[2*MANT - 1:MANT];
        end else if (pom_mant[MANT - 1] == 1'b1)begin //odbaceni bit 1?
            if (|pom_mant[MANT - 2:0] == 1'b1) begin  //bar jedna jedinica
                mant_c = {pom_mant[2*MANT - 1:MANT + 1], 1'b1}; //na vise
                
                if (mant_c[MANT - 1] == 1'b1) begin   // normalizacija
                    mant_c = mant_c >> 1;
                    exp_c = exp_c + 1;
                end
                
            end else if (|pom_mant[MANT - 2:0] != 1'b1) begin //nema nijedne jedinice
                if (pom_mant[MANT] == 1'b1) begin //poslednji bit 1?
                    mant_c = {pom_mant[2*MANT - 1:MANT + 1], 1'b1}; //na vise
                    
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
