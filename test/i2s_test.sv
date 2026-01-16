`default_nettype none

module I2SInterface_tb ();
    logic        clock, reset;
    logic        I2S_SCK, I2S_WS, I2S_SD;
    logic [17:0] data;
    logic        d_rdy_l, d_rdy_r;

    I2SInterface dut (.*);

    initial begin
        clock = 1;
        forever #5 clock = ~clock;
    end
    
    initial begin
        reset = 1;
        #100 reset = 0;
        #1000000000;
        $finish;
    end

    always_ff @(posedge I2S_SCK) begin
        if (I2S_WS) I2S_SD <= 1;
        else I2S_SD <= 0;
    end
    
endmodule : I2SInterface_tb