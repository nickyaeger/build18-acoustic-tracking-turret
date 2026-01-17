// Commented out to prevent synthesis issues
// `default_nettype none

module UARTInterface #(parameter BAUD_RATE = 115200) (
    input  logic        clock, reset,
    input  logic        data_rdy,
    input  logic [7:0]  data,
    output logic        UART_TX,
    output logic        tx_busy
);

    localparam BCLK_PERIOD = 100_000_000 / BAUD_RATE;
    logic [$clog2(BCLK_PERIOD):0] bclk_counter;
    logic [7:0] data_reg;
    logic [3:0] bit_pos;

    always_ff @(posedge clock) begin
        if (reset) begin
            UART_TX <= 1;
            tx_busy <= 0;
            data_reg <= 0;
            bclk_counter <= 0;
            bit_pos <= 0;
        end else begin
            if (data_rdy & ~tx_busy) begin
                UART_TX <= 0;
                tx_busy <= 1;
                data_reg <= data;
                bclk_counter <= 0;
                bit_pos <= 0;
            end
            if (tx_busy) begin
                if (bclk_counter == BCLK_PERIOD - 1) begin
                    bclk_counter <= 0;
                    case (bit_pos)
                        4'd8: begin
                            UART_TX <= ^data_reg;
                            bit_pos <= bit_pos + 1;
                        end
                        4'd9: begin
                            UART_TX <= 1;
                            bit_pos <= bit_pos + 1;
                        end
                        4'd10: begin
                            tx_busy <= 0;
                        end
                        default: begin
                            UART_TX <= data_reg[bit_pos];
                            bit_pos <= bit_pos + 1;
                        end
                    endcase
                end else bclk_counter <= bclk_counter + 1;
            end
        end
    end
    
endmodule : UARTInterface