module tarunes_sfc_controller #(
    parameter logic [16-1:0] HALF_PERIOD_CYCLES = 16'd162  ,
    parameter logic [16-1:0] LATCH_CYCLES       = 16'd324  ,
    parameter logic [20-1:0] POLL_GAP_CYCLES    = 20'd27000
) (
    input  var logic         clk      ,
    input  var logic         rst      ,
    input  var logic         sfc_data ,
    output var logic         sfc_latch,
    output var logic         sfc_clk  ,
    output var logic [8-1:0] buttons  
);
    localparam logic [3-1:0] STATE_GAP      = 3'd0;
    localparam logic [3-1:0] STATE_LATCH    = 3'd1;
    localparam logic [3-1:0] STATE_SAMPLE   = 3'd2;
    localparam logic [3-1:0] STATE_CLK_LOW  = 3'd3;
    localparam logic [3-1:0] STATE_CLK_HIGH = 3'd4;
    localparam logic [3-1:0] STATE_PUBLISH  = 3'd5;

    logic [3-1:0]  state    ;
    logic [20-1:0] timer    ;
    logic [5-1:0]  bit_index;
    logic [16-1:0] raw      ;
    logic [2-1:0]  data_sync;

    always_ff @ (posedge clk) begin
        if (!rst) begin
            state     <= STATE_GAP;
            timer     <= 0;
            bit_index <= 0;
            raw       <= 0;
            data_sync <= 2'b11;
            sfc_latch <= 0;
            sfc_clk   <= 1;
            buttons   <= 0;
        end else begin
            data_sync <= {data_sync[0], sfc_data};

            case ((state)) inside
                STATE_GAP: begin
                    sfc_latch <= 0;
                    sfc_clk   <= 1;
                    if ((timer == POLL_GAP_CYCLES)) begin
                        timer     <= 0;
                        raw       <= 0;
                        bit_index <= 0;
                        state     <= STATE_LATCH;
                    end else begin
                        timer <= timer + 1;
                    end
                end
                STATE_LATCH: begin
                    sfc_latch <= 1;
                    sfc_clk   <= 1;
                    if ((timer == {4'b0000, LATCH_CYCLES})) begin
                        timer <= 0;
                        state <= STATE_SAMPLE;
                    end else begin
                        timer <= timer + 1;
                    end
                end
                STATE_SAMPLE: begin
                    sfc_latch           <= 0;
                    sfc_clk             <= 1;
                    raw[bit_index[3:0]] <= !data_sync[1];
                    if ((bit_index == 5'd15)) begin
                        state <= STATE_PUBLISH;
                    end else begin
                        timer <= 0;
                        state <= STATE_CLK_LOW;
                    end
                end
                STATE_CLK_LOW: begin
                    sfc_latch <= 0;
                    sfc_clk   <= 0;
                    if ((timer == {4'b0000, HALF_PERIOD_CYCLES})) begin
                        timer <= 0;
                        state <= STATE_CLK_HIGH;
                    end else begin
                        timer <= timer + 1;
                    end
                end
                STATE_CLK_HIGH: begin
                    sfc_latch <= 0;
                    sfc_clk   <= 1;
                    if ((timer == {4'b0000, HALF_PERIOD_CYCLES})) begin
                        timer     <= 0;
                        bit_index <= bit_index + 1;
                        state     <= STATE_SAMPLE;
                    end else begin
                        timer <= timer + 1;
                    end
                end
                STATE_PUBLISH: begin
                    sfc_latch <= 0;
                    sfc_clk   <= 1;
                    buttons   <= {raw[7], raw[6], raw[5], raw[4], raw[3], raw[2], raw[0], raw[8]};
                    timer     <= 0;
                    state     <= STATE_GAP;
                end
                default: begin
                    state     <= STATE_GAP;
                    timer     <= 0;
                    bit_index <= 0;
                    sfc_latch <= 0;
                    sfc_clk   <= 1;
                end
            endcase
        end
    end
endmodule
//# sourceMappingURL=sfc_controller.sv.map
