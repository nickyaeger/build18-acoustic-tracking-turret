`default_nettype none

module Buffer_tb();
    logic        clock, reset, restart;
    logic [17:0] data_in;
    logic        data_rdy;
    logic [8:0]  read_offset;
    logic        finished_calc;
    logic [17:0] data_out;
    logic        noise_detected;
    logic        start_calc;

    Buffer dut (.*);

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
        data_in = 0;
        read_offset = 0;
        #100 data_in <= 18'd100;
        data_rdy <= 1;

        for (int i = 0; i < 1000; i++) begin
            @(posedge clock);
            data_in <= data_in + 10;
            data_rdy <= 0;
            @(posedge clock);
            data_in <= data_in + 10;
            data_rdy <= 1;
        end

        for (int i = 0; i < 500; i++) begin
            @(posedge clock);
        end

        finished_calc <= 1;
        @(posedge clock);

        for (int i = 0; i < 500; i++) begin
            @(posedge clock);
        end

        restart <= 1;
        @(posedge clock);

        for (int i = 0; i < 500; i++) begin
            @(posedge clock);
        end

        restart <= 0;
        data_in <= 0;
        data_rdy <= 1;

        @(posedge clock);
    end
    
endmodule : Buffer_tb