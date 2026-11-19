`timescale 1ns / 1ps

module jtag_dr_bypass (
    input wire tck,
    input wire tdi,
    input wire trst_n,

    // Control signals from TAP controller & IR decoder
    input wire capture_dr,
    input wire shift_dr,
    input wire select_bypass,

    // Serial bypass output
    output reg bypass_out
);

    // Capture-DR loads 0, Shift-DR captures TDI
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            bypass_out <= 1'b0;
        else if (capture_dr && select_bypass)
            bypass_out <= 1'b0;
        else if (shift_dr && select_bypass)
            bypass_out <= tdi;
    end

endmodule
