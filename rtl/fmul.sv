`timescale 1ns / 1ps

module fmul #(
    //parameter DATA_WIDTH = 32,
    parameter EXP = 8,
    parameter MANT = 23,
    parameter BIAS = 127  
)(
    input logic [EXP + MANT:0] a_i,
    input logic [EXP + MANT:0] b_i,
    output logic [EXP + MANT:0] c_o
    );
    localparam DATA_WIDTH = 1 + EXP + MANT;
    logic sign_c;
    logic [EXP - 1:0] exp_a;
    logic [EXP - 1:0] exp_b;
    logic [EXP - 1:0] exp_c;
    logic [2*MANT+1:0] pom_mant; //47 do 0
    logic [MANT - 1:0] mant_a;
    logic [MANT - 1:0] mant_b;
    logic [MANT - 1:0] mant_c;
    //odredjujemo znak izlaznog vektora, kao i eksponente i mantise ulaznih vektora
    assign sign_c = a_i[DATA_WIDTH - 1] ^ b_i[DATA_WIDTH - 1]; 
    assign exp_a = a_i[DATA_WIDTH - 2:MANT];
    assign exp_b = b_i[DATA_WIDTH - 2:MANT];
    
    assign mant_a = a_i[MANT - 1:0];
    assign mant_b = b_i[MANT - 1:0];
    
    assign c_o = (a_i == 0 || b_i == 0) ? 'h0 : {sign_c, exp_c, mant_c};
    
    always_comb begin
        //odredjujemo eksponent izlaznog vektora
        exp_c = exp_a + exp_b - BIAS;
        pom_mant = {1'b1, mant_a} * {1'b1, mant_b};
        //vrsimo normalizaciju
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
