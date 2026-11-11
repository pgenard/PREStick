`timescale 1ns/1ps

module tb_uart_present;

// ==================================================
// PARAMETERS
// ==================================================

parameter CLKS_PER_BIT = 104;
parameter CLK_PERIOD = 10;

localparam BIT_PERIOD = CLKS_PER_BIT * CLK_PERIOD;


// ==================================================
// SIGNALS
// ==================================================

reg clk;

reg uart_rxd;
wire uart_txd;

reg[255:0] key_ascii;
reg[127:0] plaintext_ascii;

reg[63:0] received_ciphertext;

reg test_pass;

reg[7:0] rx_byte;
reg[7:0] received_ascii [0:17];

integer i;
integer rx_index;


// ==================================================
// DUT
// ==================================================
top #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
) DUT (
    .clk(clk),
    .uart_rxd(uart_rxd),
    .uart_txd(uart_txd)
);

// ==================================================
// CLOCK GENERATOR
// ==================================================

initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// ==================================================
// HEX DECODER
// ==================================================

function [3:0] hex_to_bin;
    input [7:0] c;

    begin
        case(c)
            "0": hex_to_bin = 4'h0;
            "1": hex_to_bin = 4'h1;
            "2": hex_to_bin = 4'h2;
            "3": hex_to_bin = 4'h3;
            "4": hex_to_bin = 4'h4;
            "5": hex_to_bin = 4'h5;
            "6": hex_to_bin = 4'h6;
            "7": hex_to_bin = 4'h7;
            "8": hex_to_bin = 4'h8;
            "9": hex_to_bin = 4'h9;

            "A","a": hex_to_bin = 4'hA;
            "B","b": hex_to_bin = 4'hB;
            "C","c": hex_to_bin = 4'hC;
            "D","d": hex_to_bin = 4'hD;
            "E","e": hex_to_bin = 4'hE;
            "F","f": hex_to_bin = 4'hF;

            default: hex_to_bin = 4'h0;
        endcase
    end
endfunction


// ==================================================
// UART TRANSMITTER TASK
// Sends data to FPGA RX
// ==================================================

task uart_send_byte;
    input [7:0] data;

    integer j;

    begin
        // Start bit
        uart_rxd = 1'b0;

        #(BIT_PERIOD);

        // Data bits, LSB first
        for (j=0; j<8; j=j+1) begin

            uart_rxd = data[j];

            #(BIT_PERIOD);

        end

        // Stop bit
        uart_rxd = 1'b1;

        #(BIT_PERIOD);
    end
endtask


// ==================================================
// UART RECEIVER TASK
// Receives data from FPGA TX
// ==================================================

task uart_receive_byte;
    output reg [7:0] value;

    integer j;

    begin
        value = 0;

        // Wait for start bit
        @(negedge uart_txd);

        // Sample middle of start bit
        #(BIT_PERIOD/2);

        if (uart_txd !== 1'b0) begin
            $display(
                "ERROR: Invalid UART start bit at time %t",
                $time
            );
            test_pass = 0;
        end


        // Sample data bits
        for (j=0; j<8; j=j+1) begin
            #(BIT_PERIOD);
            value[j] = uart_txd;
        end


        // Sample stop bit
        #(BIT_PERIOD);

        if (uart_txd !== 1'b1) begin
            $display(
                "ERROR: Invalid UART stop bit at time %t",
                $time
            );
            test_pass = 0;
        end
    end
endtask

// ==================================================
// MAIN TEST
// ==================================================

initial begin
    $dumpfile("uart_present.vcd");

    $dumpvars(0,tb_uart_present);

    // ------------------------------------------------
    // INITIALIZATION
    // ------------------------------------------------
    clk = 0;
    uart_rxd = 1'b1;
    test_pass = 1;
    received_ciphertext = 0;
    rx_byte = 0;
    rx_index = 0;

    key_ascii =
        "00000000000000000000000000000000";

    plaintext_ascii =
        "0000000000000000";

    $display("");
    $display("====================================");
    $display("       UART + PRESENT-128 TEST");
    $display("====================================");

    // Allow FPGA power-on reset to complete.
    #(100*CLK_PERIOD);

    // ------------------------------------------------
    // RESET
    // ------------------------------------------------
    #(10*CLK_PERIOD);

    // ------------------------------------------------
    // SEND KEY
    // ------------------------------------------------
    $display("");
    $display("Sending PRESENT-128 key...");

    for (i=0; i<32; i=i+1) begin
        uart_send_byte(key_ascii[255-i*8 -: 8]);
    end

    // CR/LF
    uart_send_byte(8'h0D);
    uart_send_byte(8'h0A);

    // ------------------------------------------------
    // SEND PLAINTEXT
    // ------------------------------------------------
    $display("Sending plaintext...");

    for (i=0; i<16; i=i+1) begin
        uart_send_byte(plaintext_ascii[127-i*8 -: 8]);
    end

    // ------------------------------------------------
    // SEND FINAL CR/LF AND RECEIVE RESPONSE
    // ------------------------------------------------
    $display("");
    $display("Sending plaintext terminator...");
    $display("Waiting for FPGA ciphertext...");
    $display("");

    received_ciphertext = 64'h0;

    fork

        // --------------------------------------------
        // TRANSMIT FINAL CR/LF
        // --------------------------------------------
        begin
            uart_send_byte(8'h0D);
            uart_send_byte(8'h0A);
        end

        // --------------------------------------------
        // RECEIVE FPGA RESPONSE
        // --------------------------------------------
        begin
            for (rx_index=0; rx_index<18; rx_index=rx_index+1) begin
                uart_receive_byte(rx_byte);
                received_ascii[rx_index] = rx_byte;

                if (rx_index < 16) begin
                    received_ciphertext = {
                        received_ciphertext[59:0],
                        hex_to_bin(rx_byte)
                    };
                    $write("%c",rx_byte);
                end
            end
        end
    join

    // ------------------------------------------------
    // CHECK CR/LF
    // ------------------------------------------------

    if (received_ascii[16] != 8'h0D) begin
        $display("ERROR: Missing CR");
        test_pass = 0;
    end


    if (received_ascii[17] != 8'h0A) begin
        $display("ERROR: Missing LF");
        test_pass = 0;
    end


    // ------------------------------------------------
    // DISPLAY RESULTS
    // ------------------------------------------------

    $display("");
    $display("");
    $display("------------------------------------");
    $display("EXPECTED CIPHERTEXT:");
    $display("96DB702A2E6900AF");
    $display("");
    $display("RECEIVED CIPHERTEXT:");
    $display("%016h",received_ciphertext);
    $display("------------------------------------");

    // ------------------------------------------------
    // CHECK RESULT
    // ------------------------------------------------

    if (received_ciphertext == 64'h96DB702A2E6900AF &&
        test_pass == 1) begin
        $display("");
        $display("UART + PRESENT TEST: PASS");
    end 
    else begin
        $display("");
        $display("UART + PRESENT TEST: FAIL");
        test_pass = 0;
    end

    $display("");
    $display("====================================");

    #(10*BIT_PERIOD);

    $finish;
end

// ==================================================
// SIMULATION WATCHDOG
// ==================================================

initial begin
    #10000000;

    if (test_pass !== 1'b1) begin
        $display("ERROR: Simulation timeout or test failure!");
    end 
    else begin
        $display("ERROR: Simulation timeout!");
    end

    $finish;
end

endmodule // tb_uart_present
