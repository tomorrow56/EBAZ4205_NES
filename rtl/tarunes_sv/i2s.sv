module tarunes_i2s #(
    parameter bit TEST_TONE = 1'b0
) (
    input  var logic         clk       ,
    input  var logic         rst       ,
    input  var logic [8-1:0] sample    ,
    output var logic         bclk      ,
    output var logic         lrck      ,
    output var logic         dout      ,
    output var logic         sample_req
);
    // 27 MHz / (2 * 9) = 1.5 MHz BCLK, 1.5 MHz / 32 = 46.875 kHz LRCK.
    localparam logic [4-1:0] BCLK_HALF_DIV_LAST = 4'd8;
    // 46.875 kHz / (2 * 23) = about 1.02 kHz.
    localparam logic [5-1:0] TEST_TONE_HALF_FRAMES = 5'd22;

    logic [4-1:0]  div_count      ;
    logic [5-1:0]  bit_index      ;
    logic          bclk_reg       ;
    logic          lrck_reg       ;
    logic          dout_reg       ;
    logic [15-1:0] shift_data     ;
    logic [16-1:0] frame_data     ;
    logic          sample_req_reg ;
    logic [5-1:0]  tone_half_count;
    logic [8-1:0]  tone_sample    ;
    logic [8-1:0]  selected_sample;
    logic [16-1:0] pcm_sample     ;

    always_comb selected_sample = ((TEST_TONE) ? ( tone_sample ) : ( sample ));
    always_comb pcm_sample      = {selected_sample ^ 8'h80, 8'h00};
    always_comb bclk            = bclk_reg;
    always_comb lrck            = lrck_reg;
    always_comb dout            = dout_reg;
    always_comb sample_req      = sample_req_reg;

    always_ff @ (posedge clk) begin
        if (!rst) begin
            div_count       <= 0;
            bit_index       <= 0;
            bclk_reg        <= 0;
            lrck_reg        <= 0;
            dout_reg        <= 0;
            shift_data      <= 0;
            frame_data      <= 0;
            sample_req_reg  <= 0;
            tone_half_count <= 0;
            tone_sample     <= 8'hc0;
        end else begin
            sample_req_reg <= 0;

            if ((div_count == BCLK_HALF_DIV_LAST)) begin
                div_count <= 0;

                if ((bclk_reg)) begin
                    bclk_reg <= 0;

                    if ((bit_index == 0)) begin
                        frame_data <= pcm_sample;
                        shift_data <= pcm_sample[14:0];
                        dout_reg   <= pcm_sample[15];
                    end else if ((bit_index == 16)) begin
                        shift_data <= frame_data[14:0];
                        dout_reg   <= frame_data[15];
                    end else begin
                        shift_data <= {shift_data[13:0], 1'b0};
                        dout_reg   <= shift_data[14];
                    end

                    lrck_reg <= bit_index[4];

                    if ((bit_index == 5'd31)) begin
                        bit_index      <= 0;
                        sample_req_reg <= 1;
                        if ((tone_half_count == TEST_TONE_HALF_FRAMES)) begin
                            tone_half_count <= 0;
                            tone_sample     <= tone_sample ^ 8'h80;
                        end else begin
                            tone_half_count <= tone_half_count + 1;
                        end
                    end else begin
                        bit_index <= bit_index + 1;
                    end
                end else begin
                    bclk_reg <= 1;
                end
            end else begin
                div_count <= div_count + 1;
            end
        end
    end
endmodule
//# sourceMappingURL=i2s.sv.map
