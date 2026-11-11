`timescale 1ns/1ps

module tb_present128;

reg clk;
reg rst;
reg start;

reg[63:0] plaintext;
reg[127:0] key;

wire[63:0] ciphertext;
wire busy;
wire done;

// ==================================================
// DUT
// ==================================================
present128_core DUT (
    .clk(clk),
    .rst(rst),
    .start(start),
    .plaintext(plaintext),
    .key(key),
    .ciphertext(ciphertext),
    .busy(busy),
    .done(done)
);

// ==================================================
// CLOCK
// ==================================================
initial begin
    clk = 0;
    forever #5 clk = ~clk;

end

// ==================================================
// TEST
// ==================================================

initial begin
    $display("--------------------------------");
    $display("PRESENT-128 TEST");
    $display("--------------------------------");

    rst = 1;
    start = 0;

    key = 128'h00000000000000000000000000000000;

    plaintext = 64'h0000000000000000;

    #100;

    rst = 0;

    #20;

    $display("KEY        = %032h",key);
    $display("PLAINTEXT  = %016h",plaintext);

    start = 1;

    @(posedge clk);

    #1;

    start = 0;

    wait(done == 1'b1);

    #1;

    $display("CIPHERTEXT = %016h",ciphertext);

    if (ciphertext == 64'h96DB702A2E6900AF) begin
        $display("RESULT: PASS");
    end 
    else begin
        $display("RESULT: FAIL");
        $display("EXPECTED   = 96DB702A2E6900AF");
    end

    $display("--------------------------------");
    #100;
    $finish;

end


// ==================================================
// TIMEOUT
// ==================================================

initial begin
    #100000;
    $display("ERROR: Simulation timeout");
    $finish;
end

endmodule // tb_present128
