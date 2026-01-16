`default_nettype none

module ReadData_tb ();
    logic        clock, reset;
    logic [17:0] data;
    logic        data_rdy;
    logic [31:0] disp_val;

    ReadData dut (.*);

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

    always_ff @(posedge clock) begin
        if (reset) begin
            data <= 0;
            data_rdy <= 0;
        end else begin
            data <= data + 1;
            if (data[3:0] == 4'd15) begin
                data_rdy <= 1;
            end else begin
                data_rdy <= 0;
            end
        end
    end
    
endmodule : ReadData_tb