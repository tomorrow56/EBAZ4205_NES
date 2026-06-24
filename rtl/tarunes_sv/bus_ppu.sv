module tarunes_bus_ppu (
    input var logic                      clk    ,
    input var logic                      rst    ,
    input var logic                      stall  ,
    tarunes___bus_if__8__14.slave  ppubus ,
    tarunes___bus_if__8__13.master crombus,
    tarunes___bus_if__8__11.master vrambus
);

    logic sel_crom;
    logic sel_vram;

    // Addr sel
    always_comb sel_crom = ppubus.addr < 16'h2000;
    always_comb sel_vram = ppubus.addr >= 16'h2000 && ppubus.addr < 16'h3F00;

    // address assign
    always_comb crombus.addr = ((sel_crom) ? ( ppubus.addr ) : ( 0 ));
    always_comb vrambus.addr = ((sel_vram) ? ( ppubus.addr ) : ( 0 ));

    // Write bus assign
    always_comb vrambus.wdata = ((sel_vram) ? ( ppubus.wdata ) : ( 0 ));
    always_comb vrambus.wen   = ((sel_vram) ? ( ppubus.wen ) : ( 0 ));

    // rom
    always_comb crombus.wdata = 0;
    always_comb crombus.wen   = 0;

    // Read bus decode
    logic sel_crom_d;
    logic sel_vram_d;

    always_ff @ (posedge clk) begin
        if (!rst) begin
            sel_crom_d <= 0;
            sel_vram_d <= 0;
        end else if (!stall) begin
            sel_crom_d <= sel_crom;
            sel_vram_d <= sel_vram;
        end
    end

    always_comb begin
        if ((sel_crom_d)) begin
            ppubus.rdata = crombus.rdata;
        end else if ((sel_vram_d)) begin
            ppubus.rdata = vrambus.rdata;
        end else begin
            ppubus.rdata = 0;
        end
    end

endmodule
//# sourceMappingURL=bus_ppu.sv.map
