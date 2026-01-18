// Commented out to prevent synthesis issues
// `default_nettype none

module DisplaySamples #(parameter CALIB_VAL=0, REFRESH_RATE=10) (
    input  logic        clock, reset,
    input  logic [17:0] data,
    input  logic        data_rdy,
    output logic [31:0] disp_val
);

    import utils::*;

    localparam REFRESH_PERIOD = 100_000_000 / REFRESH_RATE;

    logic [25:0] disp_counter;
    logic [17:0] data_reg;

    always @(posedge clock) begin
        if (reset) begin
            disp_counter <= 0;
            data_reg <= 0;
            disp_val <= 0;
        end else begin
            if (data_rdy) data_reg <= data;
            if (disp_counter == REFRESH_PERIOD-1) begin
                disp_val <= {14'b0, rectify_data(data_reg, CALIB_VAL)};
                disp_counter <= 0;
            end else disp_counter <= disp_counter + 1;
        end
    end
    
endmodule : DisplaySamples