package utils;
    function logic [31:0] rectify_data(input logic [17:0] data,
                                       input logic [15:0] offset);
        logic [17:0] calibrated;
        calibrated = data + offset;
        if (calibrated[17] == 1) return {14'b0, -calibrated};
        else return {14'b0, calibrated};
    endfunction
endpackage