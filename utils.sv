package utils;
    function logic [17:0] rectify_data(input logic [17:0] data,
                                       input logic [15:0] offset);
        logic [17:0] calibrated;
        calibrated = data + offset;
        if (calibrated[17]) return -calibrated;
        else return calibrated;
    endfunction
endpackage