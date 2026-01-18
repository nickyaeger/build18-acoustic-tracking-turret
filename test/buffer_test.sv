`default_nettype none

module Buffer_tb();
    logic               clock, reset;
    logic [17:0]        data;
    logic               data_rdy;
    logic [255:0][17:0] window;
    logic               noise_detected;

    Buffer fifo (.*);

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

    initial begin
        data = 0; data_rdy = 0;
        #100 data <= 18'd100;
        data_rdy <= 1;

        for (int i = 0; i < 1000; i++) begin
            @(posedge clock);
            data <= data + i;
        end
    end
    
endmodule : Buffer_tb