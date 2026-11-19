`timescale 1ns / 1ps

module jtag_dr_bsr_cell (
    input wire tck,
    input wire trst_n,
    input wire capture_dr,
    input wire shift_dr,
    input wire update_dr,
    input wire capture_value,
    input wire serial_in,
    output reg serial_out,
    output reg update_value
);

    // Stage 1: Capture/Shift FF (updated on rising edge of TCK)
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            serial_out <= 1'b0;
        else if (capture_dr)
            serial_out <= capture_value;
        else if (shift_dr)
            serial_out <= serial_in;
    end

    // Stage 2: Update FF (updated on falling edge of TCK)
    always @(negedge tck or negedge trst_n) begin
        if (!trst_n)
            update_value <= 1'b0;
        else if (update_dr)
            update_value <= serial_out;
    end

endmodule
