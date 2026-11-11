`timescale 1ns/1ps

module present128_core(
    input wire clk,
    input wire rst,
    input wire start,

    input wire[63:0] plaintext,
    input wire[127:0] key,

    output reg[63:0] ciphertext,
    output reg busy,
    output reg done
);

// ==================================================
// REGISTERS
// ==================================================
reg[127:0] key_reg;

reg[4:0] round_count;
reg[3:0] nibble_index;

reg[3:0] fsm;


// ==================================================
// FSM STATES
// ==================================================

localparam IDLE       = 4'd0;
localparam ADD_KEY    = 4'd1;
localparam SUB_BYTES  = 4'd2;
localparam PERMUTE    = 4'd3;
localparam KEY_SBOX1  = 4'd4;
localparam KEY_SBOX2  = 4'd5;
localparam KEY_COMMIT = 4'd6;
localparam FINAL_KEY  = 4'd7;


// ==================================================
// PRESENT S-BOX
// ==================================================

function [3:0] sbox;

    input [3:0] x;

    begin
        case(x)

            4'h0: sbox = 4'hC;
            4'h1: sbox = 4'h5;
            4'h2: sbox = 4'h6;
            4'h3: sbox = 4'hB;

            4'h4: sbox = 4'h9;
            4'h5: sbox = 4'h0;
            4'h6: sbox = 4'hA;
            4'h7: sbox = 4'hD;

            4'h8: sbox = 4'h3;
            4'h9: sbox = 4'hE;
            4'hA: sbox = 4'hF;
            4'hB: sbox = 4'h8;

            4'hC: sbox = 4'h4;
            4'hD: sbox = 4'h7;
            4'hE: sbox = 4'h1;
            4'hF: sbox = 4'h2;

            default: sbox = 4'h0;

        endcase
    end

endfunction


// ==================================================
// PRESENT BIT PERMUTATION
//
// P(i) = (16*i) mod 63
//
// P(63) = 63
// ==================================================

function [63:0] permutation;

    input [63:0] x;

    integer i;

    begin

        for (i = 0; i < 63; i = i + 1)
            permutation[(16*i)%63] = x[i];

        permutation[63] = x[63];

    end

endfunction


// ==================================================
// KEY ROTATION
//
// Rotate left by 61 bits.
// ==================================================

function [127:0] rotate_key;

    input [127:0] k;

    begin

        rotate_key = {
            k[66:0],
            k[127:67]
        };

    end

endfunction


// ==================================================
// MAIN CONTROLLER
// ==================================================

always @(posedge clk) begin
    if (rst) begin
        fsm <= IDLE;
        ciphertext <= 64'd0;
        key_reg <= 128'd0;
        round_count <= 0;
        nibble_index <= 0;
        ciphertext <= 64'd0;
        busy <= 0;
        done <= 0;
    end 
    else begin

        done <= 0;

        case(fsm)


        // ==========================================
        // IDLE
        // ==========================================

        IDLE: begin

            busy <= 0;

            if (start) begin

                ciphertext <= plaintext;
                key_reg <= key;

                round_count <= 1;

                busy <= 1;

                fsm <= ADD_KEY;

            end

        end


        // ==========================================
        // ADD ROUND KEY
        // ==========================================
	ADD_KEY: begin
    ciphertext <= ciphertext ^ key_reg[127:64];
    nibble_index <= 0;
    fsm <= SUB_BYTES;
	end
	  

        // ==========================================
        // SUBSTITUTION
        //
        // One nibble per clock.
        //
        // Only one S-box is required.
        // ==========================================
        SUB_BYTES: begin

    ciphertext[(nibble_index * 4) +: 4] <=
        sbox(ciphertext[(nibble_index * 4) +: 4]);

    if (nibble_index == 15)
        fsm <= PERMUTE;
    else
        nibble_index <= nibble_index + 1'b1;

	end // case: SUB_BYTES
	  
        // ==========================================
        // PERMUTATION
        //
        // Also perform key rotation here.
        // No additional 128-bit temporary register.
        // ==========================================
        PERMUTE: begin
    ciphertext <= permutation(ciphertext);
    key_reg <= rotate_key(key_reg);
    fsm <= KEY_SBOX1;
	end

        // ==========================================
        // KEY EXPANSION
        //
        // First S-box substitution.
        // ==========================================

        KEY_SBOX1: begin

            key_reg[127:124] <=
                sbox(key_reg[127:124]);

            fsm <= KEY_SBOX2;

        end


        // ==========================================
        // KEY EXPANSION
        //
        // Second S-box substitution.
        // ==========================================

        KEY_SBOX2: begin

            key_reg[123:120] <=
                sbox(key_reg[123:120]);

            key_reg[66:62] <=
                key_reg[66:62] ^ round_count;

            fsm <= KEY_COMMIT;

        end


        // ==========================================
        // ROUND COMMIT
        // ==========================================

        KEY_COMMIT: begin

            if (round_count == 31) begin

                fsm <= FINAL_KEY;

            end else begin

                round_count <= round_count + 1'b1;

                fsm <= ADD_KEY;

            end

        end


        // ==========================================
        // FINAL ROUND KEY
        // ==========================================
        FINAL_KEY: begin
    ciphertext <= ciphertext ^ key_reg[127:64];
    busy <= 0;
    done <= 1;
    fsm <= IDLE;
	end

        // ==========================================
        // DEFAULT
        // ==========================================

        default: begin
            fsm <= IDLE;
            busy <= 0;
        end

        endcase
    end
end

endmodule // present128_core
