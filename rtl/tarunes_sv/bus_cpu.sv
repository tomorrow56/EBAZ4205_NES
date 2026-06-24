module tarunes_bus_cpu (
    input  var logic                              clk        ,
    input  var logic                              rst        ,
    input  var logic                              stall      ,
    input  var logic                              dma_busy   ,
    output var logic                              dma_start  ,
    output var logic                      [8-1:0] dma_page   ,
    output var logic                              cpu_halt   ,
    tarunes___bus_if__8__16.slave          cpubus     ,
    tarunes___bus_if__8__3.master          cpu_ppubus ,
    tarunes___bus_if__8__3.slave           dma_ppubus ,
    tarunes___bus_if__8__5.master          apubus     ,
    tarunes___bus_if__8__1.master          ctrlbus    ,
    tarunes___bus_if__8__11.slave          dma_wrambus,
    tarunes___bus_if__8__11.master         wrambus    ,
    tarunes___bus_if__8__15.master         prombus
);

    logic sel_ppu       ;
    logic sel_prom      ;
    logic sel_wram      ;
    logic sel_ctrl      ;
    logic sel_apu       ;
    logic sel_oamdma    ;
    logic oamdma_write_d;

    // Addr sel
    always_comb sel_wram   = cpubus.addr < 16'h2000;
    always_comb sel_ppu    = cpubus.addr >= 16'h2000 && cpubus.addr <= 16'h2007;
    always_comb sel_ctrl   = cpubus.addr == 16'h4016 || (cpubus.addr == 16'h4017 && !cpubus.wen);
    always_comb sel_oamdma = cpubus.addr == 16'h4014;
    always_comb sel_apu    = (cpubus.addr >= 16'h4000 && cpubus.addr <= 16'h4015 && !sel_oamdma)
        || (cpubus.addr == 16'h4017 && cpubus.wen);
    always_comb sel_prom  = cpubus.addr >= 16'h8000;
    always_comb dma_start = cpubus.wen && sel_oamdma && !oamdma_write_d && !dma_busy;
    always_comb dma_page  = cpubus.wdata;
    always_comb cpu_halt  = dma_start || dma_busy;

    // address assign
    always_comb prombus.addr    = ((sel_prom) ? ( cpubus.addr[14:0] ) : ( 0 ));
    always_comb cpu_ppubus.addr = ((dma_busy) ? ( dma_ppubus.addr ) : (sel_ppu) ? ( cpubus.addr[2:0] ) : ( 0 ));
    always_comb apubus.addr     = ((sel_apu) ? ( cpubus.addr[4:0] ) : ( 0 ));
    always_comb ctrlbus.addr    = cpubus.addr[0];
    always_comb wrambus.addr    = ((dma_busy) ? ( dma_wrambus.addr ) : (sel_wram) ? ( cpubus.addr[10:0] ) : ( 0 ));

    // Write bus assign
    always_comb wrambus.wdata     = ((dma_busy) ? ( dma_wrambus.wdata ) : (sel_wram) ? ( cpubus.wdata ) : ( 0 ));
    always_comb wrambus.wen       = ((dma_busy) ? ( dma_wrambus.wen ) : (sel_wram) ? ( cpubus.wen ) : ( 0 ));
    always_comb cpu_ppubus.wdata  = ((dma_busy) ? ( dma_ppubus.wdata ) : (sel_ppu) ? ( cpubus.wdata ) : ( 0 ));
    always_comb cpu_ppubus.wen    = ((dma_busy) ? ( dma_ppubus.wen ) : (sel_ppu) ? ( cpubus.wen ) : ( 0 ));
    always_comb apubus.wdata      = cpubus.wdata;
    always_comb apubus.wen        = !dma_busy && sel_apu && cpubus.wen;
    always_comb ctrlbus.wdata     = cpubus.wdata;
    always_comb ctrlbus.wen       = !dma_busy && sel_ctrl && cpubus.wen;
    always_comb dma_wrambus.rdata = wrambus.rdata;
    always_comb dma_ppubus.rdata  = cpu_ppubus.rdata;

    // rom
    always_comb prombus.wdata = 0;
    always_comb prombus.wen   = 0;

    // Read bus decode
    logic sel_prom_d;
    logic sel_ppu_d ;
    logic sel_wram_d;
    logic sel_ctrl_d;
    logic sel_apu_d ;

    always_ff @ (posedge clk) begin
        if (!rst) begin
            sel_prom_d     <= 0;
            sel_ppu_d      <= 0;
            sel_wram_d     <= 0;
            sel_ctrl_d     <= 0;
            sel_apu_d      <= 0;
            oamdma_write_d <= 0;
        end else if (!stall) begin
            oamdma_write_d <= cpubus.wen && sel_oamdma;
            sel_prom_d     <= sel_prom && !dma_busy;
            sel_ppu_d      <= sel_ppu && !dma_busy;
            sel_wram_d     <= sel_wram && !dma_busy;
            sel_ctrl_d     <= sel_ctrl && !dma_busy;
            sel_apu_d      <= sel_apu && !dma_busy;
        end
    end

    always_comb begin
        if ((sel_prom_d)) begin
            cpubus.rdata = prombus.rdata;
        end else if ((sel_ppu_d)) begin
            cpubus.rdata = cpu_ppubus.rdata;
        end else if ((sel_ctrl_d)) begin
            cpubus.rdata = ctrlbus.rdata;
        end else if ((sel_apu_d)) begin
            cpubus.rdata = apubus.rdata;
        end else if ((sel_wram_d)) begin
            cpubus.rdata = wrambus.rdata;
        end else begin
            cpubus.rdata = 0;
        end
    end

endmodule
//# sourceMappingURL=bus_cpu.sv.map
