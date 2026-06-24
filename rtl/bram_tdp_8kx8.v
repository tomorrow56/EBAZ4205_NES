// bram_tdp_8kx8.v
// True Dual-Port BRAM: 8KB
//   Port A: 32-bit wide, 2048 depth (word-addressed, for PS AXI write)
//   Port B: 8-bit wide, 8192 depth (byte-addressed, for NES PPU read)
//
// This module is inferred as BRAM by Vivado.
`timescale 1ns / 1ps

module bram_tdp_8kx8 (
    // Port A: PS interface (32-bit, write-capable)
    input  wire        clka,
    input  wire        ena,
    input  wire [3:0]  wea,
    input  wire [10:0] addra,   // 11-bit: 2048 x 32-bit words
    input  wire [31:0] dina,
    output reg  [31:0] douta,

    // Port B: NES PPU interface (8-bit, read-only)
    input  wire        clkb,
    input  wire        enb,
    input  wire [3:0]  web,     // always 0 for NES (read-only)
    input  wire [12:0] addrb,   // 13-bit: 8192 x 8-bit bytes
    input  wire [31:0] dinb,    // unused (tied to 0)
    output reg  [7:0]  doutb
);
    // Memory array: 2048 x 32-bit = 8192 bytes
    reg [31:0] mem [0:2047];

    // Port A: 32-bit read/write
    always @(posedge clka) begin
        if (ena) begin
            if (wea[0]) mem[addra][7:0]   <= dina[7:0];
            if (wea[1]) mem[addra][15:8]  <= dina[15:8];
            if (wea[2]) mem[addra][23:16] <= dina[23:16];
            if (wea[3]) mem[addra][31:24] <= dina[31:24];
            douta <= mem[addra];
        end
    end

    // Port B: 8-bit read (byte-addressed)
    // addrb[12:2] = word index, addrb[1:0] = byte select within word
    always @(posedge clkb) begin
        if (enb) begin
            case (addrb[1:0])
                2'b00: doutb <= mem[addrb[12:2]][7:0];
                2'b01: doutb <= mem[addrb[12:2]][15:8];
                2'b10: doutb <= mem[addrb[12:2]][23:16];
                2'b11: doutb <= mem[addrb[12:2]][31:24];
            endcase
        end
    end

endmodule
