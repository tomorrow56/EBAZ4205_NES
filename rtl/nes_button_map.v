// nes_button_map.v
// Maps EBAZ4205 adapter board buttons (5 buttons) to NES controller buttons (8 bits)
//
// NES controller button bit mapping (standard):
//   bit 7: A
//   bit 6: B
//   bit 5: SELECT
//   bit 4: START
//   bit 3: UP
//   bit 2: DOWN
//   bit 1: LEFT
//   bit 0: RIGHT
//
// EBAZ4205 button assignment:
//   BTN[0] (T19) -> A
//   BTN[1] (P19) -> B
//   BTN[2] (U20) -> SELECT
//   BTN[3] (U19) -> START
//   BTN[4] (V20) -> (not assigned / reserved)
//
// Note: Direction buttons (UP/DOWN/LEFT/RIGHT) are not connected due to
//       insufficient button count. They remain inactive (0) in this implementation.
//       Future extension: connect an additional joystick or D-pad via GPIO.
`timescale 1ns / 1ps

module nes_button_map (
    input  wire [4:0] btn_debounced,  // debounced button inputs [4:0]
    output wire [7:0] nes_buttons     // NES button byte for controller1
);
    // Bit assignment
    // NES: {A, B, SELECT, START, UP, DOWN, LEFT, RIGHT}
    assign nes_buttons = {
        btn_debounced[0],  // bit7: A     <- BTN[0]
        btn_debounced[1],  // bit6: B     <- BTN[1]
        btn_debounced[2],  // bit5: SELECT<- BTN[2]
        btn_debounced[3],  // bit4: START <- BTN[3]
        1'b0,              // bit3: UP    (not connected)
        1'b0,              // bit2: DOWN  (not connected)
        1'b0,              // bit1: LEFT  (not connected)
        1'b0               // bit0: RIGHT (not connected)
    };
endmodule
