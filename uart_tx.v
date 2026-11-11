`timescale 1ns/1ps

module uart_tx #(
    parameter CLKS_PER_BIT = 104
)(
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire transmit,

    output reg tx,
    output reg busy
);

localparam IDLE  = 2'd0;
localparam START = 2'd1;
localparam DATA  = 2'd2;
localparam STOP  = 2'd3;

reg[1:0] state;
reg[15:0] clk_count;
reg[2:0] bit_index;
reg[7:0] tx_shift;

always @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
        tx <= 1'b1;
        busy <= 1'b0;
        clk_count <= 0;
        bit_index <= 0;
        tx_shift <= 0;
    end

    else begin

        case(state)

        IDLE: begin
            tx <= 1'b1;
            busy <= 1'b0;
            clk_count <= 0;

            if (transmit) begin
                tx_shift <= data_in;
                busy <= 1'b1;
                state <= START;
            end
        end

        START: begin
            tx <= 1'b0;

            if (clk_count == CLKS_PER_BIT-1) begin
                clk_count <= 0;
                bit_index <= 0;
                state <= DATA;
            end else begin
                clk_count <= clk_count + 1'b1;
            end
        end

        DATA: begin
            tx <= tx_shift[bit_index];

            if (clk_count == CLKS_PER_BIT-1) begin
                clk_count <= 0;

                if (bit_index == 7)
                    state <= STOP;
                else
                    bit_index <= bit_index + 1'b1;

            end else begin
                clk_count <= clk_count + 1'b1;
            end
        end

        STOP: begin
            tx <= 1'b1;

            if (clk_count == CLKS_PER_BIT-1) begin
                clk_count <= 0;
                state <= IDLE;
            end else begin
                clk_count <= clk_count + 1'b1;
            end
        end

        default: state <= IDLE;

        endcase
    end
end

endmodule // uart_tx
