// Commented out to prevent synthesis issues
// `default_nettype none

module ChipInterface (  
    input  logic        CLOCK_100, // 100 MHz Clock
    output logic        i2s0_sck, i2s0_ws, 
    input  logic        i2s0_sd,
    output logic        uart0_tx,
    input  logic [15:0] SW,
    input  logic [ 3:0] BTN,
    output logic [ 7:0] D0_SEG, D1_SEG,
    output logic [ 3:0] D0_AN, D1_AN
);

    logic [ 6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7;
    logic [31:0] BCD;

    SevenSegmentDisplay ssd (.BCD7(BCD[31:28]),
                             .BCD6(BCD[27:24]),
                             .BCD5(BCD[23:20]),
                             .BCD4(BCD[19:16]),
                             .BCD3(BCD[15:12]),
                             .BCD2(BCD[11:8]),
                             .BCD1(BCD[7:4]),
                             .BCD0(BCD[3:0]),
                             .blank(8'b0),
                             .HEX7,
                             .HEX6,
                             .HEX5,
                             .HEX4,
                             .HEX3,
                             .HEX2,
                             .HEX1,
                             .HEX0);

    SSegDisplayDriver ssdd (.clk(CLOCK_100),
                            .reset(BTN[0]),
                            .HEX0,
                            .HEX1,
                            .HEX2,
                            .HEX3,
                            .HEX4,
                            .HEX5,
                            .HEX6,
                            .HEX7,
                            .dpoints(8'b0000_0000),
                            .D1_AN(D0_AN),
                            .D2_AN(D1_AN),
                            .D1_SEG(D0_SEG),
                            .D2_SEG(D1_SEG));

    logic [17:0] data;
    logic        d_rdy_l, d_rdy_r;

    I2SInterface i2s0 (.clock(CLOCK_100),
                       .reset(BTN[0]),
                       .I2S_SCK(i2s0_sck),
                       .I2S_WS(i2s0_ws),
                       .I2S_SD(i2s0_sd),
                       .data,
                       .d_rdy_l,
                       .d_rdy_r);
    
    ReadData #(.CALIB_VAL(13'd7040))
            rd0 (.clock(CLOCK_100),
                 .reset(BTN[0]),
                 .data,
                 .data_rdy(d_rdy_l),
                 .disp_val(BCD)
                 );

    logic [7:0]  angle;
    logic [26:0] clk_counter;
    logic        tx_busy, data_rdy_uart;

    assign data_rdy_uart = (clk_counter == 0 & ~tx_busy);

    always_ff @(posedge CLOCK_100) begin
        if (BTN[0]) begin
            clk_counter <= 0;
            angle <= 0;
        end else begin
            if (clk_counter == 27'd99_999_999) begin
                clk_counter <= 0;
                if (angle == 8'd180) angle <= 0;
                else angle <= angle + 1;
            end else clk_counter <= clk_counter + 1;
        end
    end

    UARTInterface uart0 (.clock(CLOCK_100),
                         .reset(BTN[0]),
                         .data_rdy(data_rdy_uart),
                         .data(angle),
                         .UART_TX(uart0_tx),
                         .tx_busy);

endmodule : ChipInterface