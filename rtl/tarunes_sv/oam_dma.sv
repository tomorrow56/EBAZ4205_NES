module tarunes_oam_dma (
    input  var logic                              clk       ,
    input  var logic                              rst       ,
    input  var logic                              stall     ,
    input  var logic                              start     ,
    input  var logic                      [8-1:0] page      ,
    output var logic                              busy      ,
    tarunes___bus_if__8__11.master         wrambus   ,
    tarunes___bus_if__8__3.master          ppu_regbus
);
    typedef enum logic [2-1:0] {
        dma_state_t_IDLE,
        dma_state_t_READ,
        dma_state_t_WRITE
    } dma_state_t;

    dma_state_t          state     ;
    logic       [8-1:0]  page_latch;
    logic       [8-1:0]  index     ;
    logic       [16-1:0] dma_addr  ;

    always_comb busy             = state != dma_state_t_IDLE;
    always_comb dma_addr         = {page_latch, index};
    always_comb wrambus.addr     = dma_addr[10:0];
    always_comb wrambus.wen      = 0;
    always_comb wrambus.wdata    = 0;
    always_comb ppu_regbus.addr  = 3'd4;
    always_comb ppu_regbus.wen   = state == dma_state_t_WRITE;
    always_comb ppu_regbus.wdata = wrambus.rdata;

    always_ff @ (posedge clk) begin
        if (!rst) begin
            state      <= dma_state_t_IDLE;
            page_latch <= 0;
            index      <= 0;
        end else if (!stall) begin
            case ((state))
                dma_state_t_IDLE: begin
                    if ((start)) begin
                        page_latch <= page;
                        index      <= 0;
                        state      <= dma_state_t_READ;
                    end
                end
                dma_state_t_READ: begin
                    state <= dma_state_t_WRITE;
                end
                dma_state_t_WRITE: begin
                    if ((index == 8'hFF)) begin
                        state <= dma_state_t_IDLE;
                    end else begin
                        index <= index + 1;
                        state <= dma_state_t_READ;
                    end
                end
                default: begin
                    state <= dma_state_t_IDLE;
                end
            endcase
        end
    end
endmodule
//# sourceMappingURL=oam_dma.sv.map
