// Commented out to prevent synthesis issues
// `default_nettype none

module ChipInterface (  
    input  logic        CLOCK_100, // 100 MHz Clock
    output logic        i2s0_sck, i2s0_ws, 
    input  logic        i2s0_sd,
    output logic        i2s1_sck, i2s1_ws, 
    input  logic        i2s1_sd,
    output logic        uart0_tx,
    input  logic [15:0] SW,
    output logic [15:0] LD,
    input  logic [ 3:0] BTN,
    output logic [ 7:0] D0_SEG, D1_SEG,
    output logic [ 3:0] D0_AN, D1_AN
);

    import utils::*;

    logic [ 6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7;
    logic [31:0] BCD_LT, BCD_RT;

    SevenSegmentDisplay ssd (.BCD7(BCD_RT[15:12]),
                             .BCD6(BCD_RT[11:8]),
                             .BCD5(BCD_RT[7:4]),
                             .BCD4(BCD_RT[3:0]),
                             .BCD3(BCD_LT[15:12]),
                             .BCD2(BCD_LT[11:8]),
                             .BCD1(BCD_LT[7:4]),
                             .BCD0(BCD_LT[3:0]),
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

    logic [1:0][17:0] data;
    logic [1:0]       data_rdy;

    I2SInterface i2s0 (.clock(CLOCK_100),
                       .reset(BTN[0]),
                       .I2S_SCK(i2s0_sck),
                       .I2S_WS(i2s0_ws),
                       .I2S_SD(i2s0_sd),
                       .data(data[0]),
                       .d_rdy_l(data_rdy[0]),
                       .d_rdy_r());

    I2SInterface i2s1 (.clock(CLOCK_100),
                       .reset(BTN[0]),
                       .I2S_SCK(i2s1_sck),
                       .I2S_WS(i2s1_ws),
                       .I2S_SD(i2s1_sd),
                       .data(data[1]),
                       .d_rdy_l(data_rdy[1]),
                       .d_rdy_r());
    
    DisplaySamples #(.CALIB_VAL(13'd7296))
                rd0 (.clock(CLOCK_100),
                     .reset(BTN[0]),
                     .data(data[0]),
                     .data_rdy(data_rdy[0]),
                     .disp_val(BCD_LT));

    DisplaySamples #(.CALIB_VAL(13'd7040))
                rd1 (.clock(CLOCK_100),
                     .reset(BTN[0]),
                     .data(data[1]),
                     .data_rdy(data_rdy[1]),
                     .disp_val(BCD_RT));

    logic [1:0] noise_detected;

    assign LD[ 7:0] = (noise_detected[0]) ? 8'b1111_1111 : 0;
    assign LD[15:8] = (noise_detected[1]) ? 8'b1111_1111 : 0;

    Buffer #(.CALIB_VAL(13'd7296))
           buf0 (.clock(CLOCK_100),
                 .reset(BTN[0]),
                 .data(data[0]),
                 .data_rdy(data_rdy[0]),
                 .window(),
                 .noise_detected(noise_detected[0]));

    Buffer #(.CALIB_VAL(13'd7040))
           buf1 (.clock(CLOCK_100),
                 .reset(BTN[0]),
                 .data(data[1]),
                 .data_rdy(data_rdy[1]),
                 .window(),
                 .noise_detected(noise_detected[1]));

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