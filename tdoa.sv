// Commented out to prevent synthesis issues
// `default_nettype none

module Buffer #(parameter DEPTH=512, WINDOW_SIZE=5, THRESHOLD=4_096, CALIB_VAL=0) (
    input  logic                        clock, reset,
    input  logic [17:0]                 data,
    input  logic                        data_rdy,
    output logic [DEPTH-1:0][17:0]      window,
    output logic                        noise_detected
);

    import utils::*;

    localparam TOTAL = WINDOW_SIZE * THRESHOLD;
    localparam SUM_WIDTH = $clog2(WINDOW_SIZE) + 18;
    logic [SUM_WIDTH-1:0] sum;

    always_comb begin
        sum = 0;
        for (int i = 0; i < WINDOW_SIZE; i++)
            sum = sum + window[i];
        noise_detected = (sum > TOTAL);
    end

    always_ff @(posedge clock) begin
        if (reset) window <= 0;
        else if (data_rdy)
            window <= {window[DEPTH-1:1], 
                       rectify_data(data, CALIB_VAL)};
    end
    
endmodule : Buffer