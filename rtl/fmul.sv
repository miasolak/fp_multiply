`timescale 1ns / 1ps

module fmul #(
    parameter EXP = 8,
    parameter MANT = 23,
    parameter BIAS = 127  
)(
    input  logic [EXP + MANT:0] a,
    input  logic [EXP + MANT:0] b,
    output logic [EXP + MANT:0] y,
    output logic invalid,
    output logic overflow,
    output logic underflow,
    output logic inexact
);

    localparam DATA_WIDTH = 1 + EXP + MANT;

    logic sign_c;
    logic [EXP - 1:0] exp_a;
    logic [EXP - 1:0] exp_b;
    logic [EXP - 1:0] exp_c;
    logic [2*MANT+1:0] pom_mant;
    logic [MANT - 1:0] mant_a;
    logic [MANT - 1:0] mant_b;
    logic [MANT - 1:0] mant_c;

    logic a_isZero, a_isSub, a_isNaN, a_isInf;
    logic b_isZero, b_isSub, b_isNaN, b_isInf;

    logic [MANT:0] mant_pom;
    
    logic signed [EXP+1:0] exp_work;

    assign sign_c = a[DATA_WIDTH - 1] ^ b[DATA_WIDTH - 1]; 
    assign exp_a  = a[DATA_WIDTH - 2:MANT];
    assign exp_b  = b[DATA_WIDTH - 2:MANT];
    assign mant_a = a[MANT - 1:0];
    assign mant_b = b[MANT - 1:0];
    
    always_comb begin
    
        invalid = 0;
        overflow = 0;
        underflow = 0;
        inexact = 0;
        y = 0;
   
        exp_work = 0;
        pom_mant = 0;
        mant_pom = 0;
        y = 0;
        a_isZero = 0;
        a_isSub  = 0;
        a_isInf  = 0;
        a_isNaN  = 0;
        b_isZero = 0;
        b_isSub  = 0;
        b_isInf  = 0;
        b_isNaN  = 0;

        exp_c    = 0;
        mant_c   = 0;
        pom_mant = 0;   // added
        mant_pom = 0;   // added
        y      = 0;   // added

        if (exp_a == 0 && mant_a == 0) begin
            a_isZero = 1;
        end else if (exp_a == 0 && mant_a != 0) begin
            a_isSub = 1;
        end else if (exp_a == {EXP{1'b1}} && mant_a == 0) begin
            a_isInf = 1;
        end else if (exp_a == {EXP{1'b1}} && mant_a != 0) begin
            a_isNaN = 1;
        end
        
        if (exp_b == 0 && mant_b == 0) begin
            b_isZero = 1;
        end else if (exp_b == 0 && mant_b != 0) begin
            b_isSub = 1;
        end else if (exp_b == {EXP{1'b1}} && mant_b == 0) begin
            b_isInf = 1;
        end else if (exp_b == {EXP{1'b1}} && mant_b != 0) begin
            b_isNaN = 1;
        end
        
        if (a_isNaN || b_isNaN) begin
        // at least one is NaN -> c = NaN
          //  invalid = 1;  
            exp_c = {EXP{1'b1}};
            mant_c[MANT-1]   = 1'b1; 
            mant_c[MANT-2:0] = 0;
            y = {1'b0, exp_c, mant_c};
        end else if (((a_isZero || a_isSub) && b_isInf) || (a_isInf && (b_isZero || b_isSub))) begin
        // 0 * infinity  or  subnormal * infinity -> c = NaN, inv flag
            invalid = 1;
            exp_c = {EXP{1'b1}};
            mant_c[MANT-1]   = 1'b1;
            mant_c[MANT-2:0] = 0;
            y = {1'b0, exp_c, mant_c};
        end else if (a_isInf || b_isInf) begin
         // one is infinite -> c = inf
            exp_c = {EXP{1'b1}};
            mant_c = 0;
            y = {sign_c, exp_c, mant_c};
        end else if (a_isZero || b_isZero || a_isSub || b_isSub) begin
        //zero or subnormal -> c = zero
            exp_c = 0;
            mant_c = 0;
            y = {sign_c, exp_c, mant_c};
        end else begin
            //exp_c = exp_a + exp_b - BIAS;
            exp_work = $signed({1'b0, exp_a}) + $signed({1'b0, exp_b}) - BIAS;
            pom_mant = {1'b1, mant_a} * {1'b1, mant_b};

            if (pom_mant[2*MANT+1] == 1'b1) begin
                pom_mant = pom_mant >> 1;
                exp_work = exp_work + 1;
            end

            if (pom_mant[MANT - 1] == 1'b0) begin
                mant_c = pom_mant[2*MANT - 1:MANT];
            end else begin
                if (|pom_mant[MANT - 2:0]) begin
                    mant_pom = {1'b0, pom_mant[2*MANT - 1:MANT]} + 1'b1;
                    if (mant_pom[MANT] == 1'b1) begin
                        mant_c = {MANT{1'b0}};
                        exp_work = exp_work + 1;;
                    end else begin
                        mant_c = mant_pom[MANT-1:0];
                    end
                end else begin
                    if (pom_mant[MANT] == 1'b1) begin
                        mant_pom = {1'b0, pom_mant[2*MANT - 1:MANT]} + 1'b1;
                        if (mant_pom[MANT] == 1'b1) begin
                            mant_c = {MANT{1'b0}};
                            exp_work = exp_work + 1;;
                        end else begin
                            mant_c = mant_pom[MANT-1:0];
                        end
                    end else begin
                        mant_c = pom_mant[2*MANT - 1:MANT];
                    end
                end
            end
            
            if (exp_work >= 255) begin
                y = {sign_c, {EXP{1'b1}}, {MANT{1'b0}}};
                overflow = 1;
                inexact = 1;
            end else if (exp_work <= 0) begin
                y = {sign_c, {EXP{1'b0}}, {MANT{1'b0}}};
                underflow = 1;
                inexact = 1;
            end else begin
                exp_c = exp_work[EXP-1:0];
                y = {sign_c, exp_c, mant_c};
            end
        end
        
         
    end 

endmodule