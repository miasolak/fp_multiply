module fmul_tb;
    parameter DATA_WIDTH = 32;
    reg [DATA_WIDTH - 1:0] a_i;
    reg [DATA_WIDTH - 1:0] b_i;
    wire [DATA_WIDTH - 1:0] c_o;
    
    //Instanciranje DUT-a
    fmul dut (
    .a_i (a_i),
    .b_i (b_i),
    .c_o (c_o)
    );
    
    initial begin
        a_i = 32'h3F800000;   // 1.0
        b_i = 32'h3F800000;   // 1.0
        #10;
        //expected = 32'h3F800000

        a_i = 32'h3F800000;   // 1.0
        b_i = 32'h40000000;   // 2.0
        #10;
        //expected = 32'h40000000
        
        a_i = 32'h3FC00000;   // 1.5
        b_i = 32'h40000000;   // 2.0
        #10;
        //expected = 32'h40400000
        
        a_i = 32'hBF800000;   // -1.0
        b_i = 32'h40000000;   // 2.0
        #10;
        //expected = 32'hC0000000
        
        a_i = 32'h00000000;   // 0
        b_i = 32'h40000000;   // 2.0
        #10;
        //expected = 32'h00000000
    
    end     
    
endmodule
