// Commented out to prevent synthesis issues
// `default_nettype none

module Buffer #(parameter DEPTH=512, WINDOW_SIZE=5, THRESHOLD=4_096, CALIB_VAL=0) (
    input  logic                     clock, reset, restart,
    input  logic [17:0]              data_in,
    input  logic                     data_rdy,
    input  logic [$clog2(DEPTH)-1:0] read_offset,
    input  logic                     finished_calc,
    output logic [17:0]              data_out,
    output logic                     noise_detected,
    output logic                     start_calc
);

    import utils::*;

    localparam ADDR_W = $clog2(DEPTH);
    localparam SUM_WIDTH = $clog2(WINDOW_SIZE) + 18;

    typedef enum logic [2:0] { WAIT, SHIFT, SOUND, RESTART_0, RESTART_1, FLUSH } state_t;
    state_t state, next_state;

    blk_mem_gen_1 cbuf (.clka(clock),
                        .addra(addr),
                        .dina(rectified),
                        .douta(data_out),
                        .wea(we));

    // Address and data
    logic [ADDR_W-1:0] addr, write_ptr, read_ptr;
    logic [17:0]       rectified;
    logic              we;

    assign read_ptr = write_ptr - read_offset - 1;
    assign rectified = rectify_data(data_in, CALIB_VAL);

    // Running sum
    logic [WINDOW_SIZE-1:0][17:0] window;
    logic [SUM_WIDTH-1:0]         sum;

    // Counter for shifting noisy samples to middle of buffer
    logic [7:0] shift_counter;
    logic       en_counter, cl_counter;

    logic [8:0] flush_counter;
    logic       cl_flush;

    always_ff @(posedge clock) begin
        if (reset) state <= WAIT;
        else state <= next_state;
    end

    always_comb begin
        sum = '0;
        for (int i = 0; i < WINDOW_SIZE; i++)
            sum = sum + window[i];
        noise_detected = (sum > (WINDOW_SIZE * THRESHOLD));
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            write_ptr <= '0;
        end else if (data_rdy & we) begin
            write_ptr <= write_ptr + 1'b1;
            window <= {window[WINDOW_SIZE-2:0], rectified};
        end
    end

    always_ff @(posedge clock) begin
        if (reset | cl_counter) 
            shift_counter <= '0;
        else if (en_counter)
            shift_counter <= shift_counter + 1'b1; 
    end

    always_ff @(posedge clock) begin
        if (reset) flush_counter <= 0;
        else if (state == FLUSH & data_rdy)
            flush_counter <= flush_counter + 1;
    end

    always_comb begin
        next_state = WAIT;
        we = 1'b0;
        addr = write_ptr;
        cl_counter = 1'b0;
        cl_flush = 1'b0;
        en_counter = 1'b0;
        start_calc = 1'b0;
        case (state)
            WAIT: begin
                if (data_rdy) begin
                    we = 1'b1;
                    // en_counter = 1'b1;
                end
                if (noise_detected) begin
                    next_state = SHIFT;
                end
            end
            SHIFT: begin
                if (data_rdy) begin
                    en_counter = 1'b1;
                    we = 1'b1;
                end
                if (shift_counter == 8'd255) begin
                    next_state = SOUND;
                    en_counter = 1'b0;
                    cl_counter = 1'b1;
                    start_calc = 1'b1;
                end else next_state = SHIFT;
            end
            SOUND: begin
                addr = read_ptr;
                if (finished_calc) next_state = RESTART_0;
                else next_state = SOUND;
            end
            RESTART_0: begin
                if (restart) next_state = RESTART_1;
                else next_state = RESTART_0;
            end
            RESTART_1: begin
                if (~restart) next_state = FLUSH;
                else next_state = RESTART_1;
            end
            FLUSH: begin
                if (data_rdy) we = 1'b1;
                if (flush_counter == 9'd511) begin
                    next_state = WAIT;
                    cl_flush = 1'b1;
                end else begin
                    next_state = FLUSH;
                end
            end
            default: next_state = WAIT;
        endcase
    end
    
endmodule : Buffer

module TDOA #(parameter DEPTH=512) (
    input  logic                     clock, reset, restart,
    input  logic                     ready,
    input  logic [17:0]              din0, din1,
    output logic [$clog2(DEPTH)-1:0] addr0, addr1, 
    output logic                     done, 
    output logic signed [7:0]        k_hat // shift result
);

    localparam T_MAX = 42;
    localparam MIDPOINT = DEPTH / 2;
    localparam N = 2*T_MAX + 1;
    localparam K = 2*T_MAX + 1;
    localparam SCORE_WIDTH = 36 + $clog2(N);

    typedef enum logic [2:0] { IDLE, FETCH, MULT, ADD, EVAL, DONE, RESTART_0, RESTART_1 } state_t;
    state_t state, next_state;

    logic load_data, clear_score;

    // Iteration variables
    logic [9:0] n, next_n;
    logic signed [9:0] k, next_k;

    // Multiplication variables
    logic [17:0] A, B;
    logic [35:0] P;

    mult_gen_0 mult (.CLK(clock), .A, .B, .P);

    // Correlation score
    logic [SCORE_WIDTH-1:0]   current_score, max_score; 
    logic                     new_max, clear_max;

    always_ff @(posedge clock) begin
        if (reset) state <= IDLE;
        else state <= next_state;
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            A <= '0; B <= '0;
        end else begin
            if (load_data) begin
                A <= din0; B <= din1;
            end
        end 
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            n <= 0; k <= 0;
        end else begin
            n <= next_n; k <= next_k;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            current_score <= 0;
            max_score <= 0;
            k_hat <= 0;
        end else begin
            if (clear_score) current_score <= '0;
            else if (state == ADD) begin
                current_score <= current_score + P; 
            end
            if (new_max) begin
                max_score <= current_score;
                k_hat <= k;
            end else if (clear_max) begin
                max_score <= '0;
            end
        end
    end

    always_comb begin
        next_state = IDLE;
        load_data = 1'b0;
        next_n = n; next_k = k;
        addr0 = '0; addr1 = '0;
        clear_score = 1'b0;
        new_max = '0;
        clear_max = 1'b0;
        done = 1'b0;
        case (state)
            IDLE: begin
                if (ready) begin
                    clear_max = 1'b1;
                    clear_score = 1'b1;
                    next_state = FETCH;
                    next_n = 0;
                    next_k = -T_MAX;
                end 
            end
            FETCH: begin
                next_state = MULT;
                load_data = 1'b1;
                addr0 = MIDPOINT - T_MAX + n;
                addr1 = MIDPOINT - T_MAX + n + k;
            end
            MULT: begin
                next_state = ADD;
            end
            ADD: begin
                if (n == N-1) begin
                    next_state = EVAL;
                end else begin
                    next_state = FETCH;
                    next_n = n + 1;
                end
            end
            EVAL: begin
                if (k == T_MAX) begin
                    next_state = DONE;
                end else begin
                    next_state = FETCH;
                    next_k = k + 1;
                    next_n = 0;
                    clear_score = 1'b1;
                end
                if (current_score > max_score) begin
                    new_max = 1;
                end
            end
            DONE: begin
                next_state = RESTART_0;
                done = 1;
            end
            RESTART_0: begin
                if (restart) next_state = RESTART_1;
                else next_state = RESTART_0;
            end
            RESTART_1: begin
                if (~restart) next_state = IDLE;
                else next_state = RESTART_1;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule : TDOA