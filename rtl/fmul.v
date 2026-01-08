`timescale 1ns / 1ps

module fmul(
    input [31:0] a_i,
    input [31:0] b_i,
    output wire [31:0] c_o
    );
    
    wire sign_c;
    reg [8:0] exp_c;
    reg [47:0] pom_mant;
    reg [22:0] mant_c_preround;
    reg [22:0] mant_c;
    wire [31:0] bias;
    assign sign_c = a_i[31] ^ b_i[31]; //ovo je moglo i u always-u da se ne bi stalno pisalo assign itd...
//    always @(*)begin
//      sign_c = a_i[31] ^ b_i[31];
//    end
    assign bias = 127;
    assign c_o = (a_i == 0 || b_i == 0) ? 'h0 : {sign_c, exp_c, mant_c};
    
    always @(*)begin
        exp_c = a_i[30:23] + b_i[30:23] - bias;
        pom_mant = {1'b1, a_i[22:0]} * {1'b1, b_i[22:0]};
        if (pom_mant[47] == 1'b1) begin //10 xx normalizacija
            pom_mant = pom_mant >> 1;     //sad je pom sigurno oblika: 01 46bita
            exp_c = exp_c + 1;
        end
        if (pom_mant[22] == 1'b0)begin  //01 xx
            mant_c = pom_mant[45:23];
        end else if (pom_mant[22] == 1'b1)begin //odbaceni bit 1?
            if (|pom_mant[21:0] == 1'b1) begin  //bar jedna jedinica
                mant_c = {pom_mant[45:24], 1'b1}; //na vise
                
                if (mant_c[22] == 1'b1) begin   // normalizacija
                    mant_c = mant_c >> 1;
                    exp_c = exp_c + 1;
                end
                
            end else if (|pom_mant[21:0] != 1'b1) begin //nema nijedne jedinice
                if (pom_mant[23] == 1'b1) begin //poslednji bit 1?
                    mant_c = {pom_mant[45:24], 1'b1}; //na vise
                    
                    if (mant_c[22] == 1'b1) begin   //normalizacija
                        mant_c = mant_c >> 1;
                        exp_c = exp_c + 1;
                    end
                    
                end else if (pom_mant[23] == 1'b0) begin //poslednji bit 0?
                    mant_c = pom_mant[45:23];
                end
           end
         end
     end

    

    
    
endmodule
