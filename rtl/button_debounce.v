// button_debounce.v
// Push button debounce circuit for EBAZ4205
// Debounce time: ~10ms at 27MHz clock (270,000 cycles)
`timescale 1ns / 1ps

module button_debounce #(
    parameter DEBOUNCE_CYCLES = 270000  // ~10ms at 27MHz
) (
    input  wire clk,
    input  wire rst_n,
    input  wire btn_in,      // raw button input (active high)
    output reg  btn_out      // debounced output (active high)
);
    reg [19:0] counter;
    reg        btn_sync0, btn_sync1;

    // Two-stage synchronizer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync0 <= 1'b0;
            btn_sync1 <= 1'b0;
        end else begin
            btn_sync0 <= btn_in;
            btn_sync1 <= btn_sync0;
        end
    end

    // Debounce counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter  <= 20'd0;
            btn_out  <= 1'b0;
        end else begin
            if (btn_sync1 == btn_out) begin
                counter <= 20'd0;
            end else begin
                counter <= counter + 20'd1;
                if (counter >= DEBOUNCE_CYCLES - 1) begin
                    counter <= 20'd0;
                    btn_out <= btn_sync1;
                end
            end
        end
    end
endmodule
