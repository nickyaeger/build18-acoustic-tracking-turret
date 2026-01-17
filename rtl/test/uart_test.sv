`default_nettype none

module UARTInterface_tb ();
    logic        clock, reset;
    logic        data_rdy;
    logic [7:0]  data;
    logic        UART_TX;
    logic        tx_busy;

    UARTInterface dut (.*);

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

    assign data_rdy = ~tx_busy;

    always_ff @(posedge clock) begin
        if (reset) data <= 0;
        else data <= data + 1;
    end
    
endmodule : UARTInterface_tb