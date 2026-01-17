// Commented out to prevent synthesis issues
// `default_nettype none

module I2SInterface (
    input  logic        clock, reset,
    output logic        I2S_SCK,
    output logic        I2S_WS,
    input  logic        I2S_SD,
    output logic [17:0] data,
    output logic        d_rdy_l, d_rdy_r
);

    logic [4:0] sck_counter, ws_counter;

    assign d_rdy_l = (ws_counter > 5'd17 & ~I2S_WS);
    assign d_rdy_r = (ws_counter > 5'd17 & I2S_WS);

    always_ff @(posedge clock) begin
        if (reset) begin
            sck_counter <= 5'd0;
            ws_counter <= 5'd0;
            I2S_SCK <= 1;
            I2S_WS <= 1;
            data <= 18'd0;
        end else begin
            sck_counter <= sck_counter + 1;
            if (sck_counter == 5'd15) begin
                I2S_SCK <= 0;
                ws_counter <= ws_counter + 1;
                if (ws_counter == 5'd31)
                    I2S_WS <= ~I2S_WS;
            end
            if (sck_counter == 5'd31)
                I2S_SCK <= 1;
            if (sck_counter == 5'd15 & ws_counter < 5'd18)
                data[5'd17 - ws_counter] = I2S_SD;
        end
    end
    
endmodule : I2SInterface