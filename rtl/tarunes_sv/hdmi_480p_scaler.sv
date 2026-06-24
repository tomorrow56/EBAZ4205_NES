module tarunes_hdmi_480p_scaler (
    input  var logic          clk             ,
    input  var logic          rst             ,
    input  var logic [9-1:0]  core_cycle      ,
    input  var logic [9-1:0]  core_scanline   ,
    input  var logic [6-1:0]  core_pixel_index,
    output var logic [8-1:0]  hdmi_r          ,
    output var logic [8-1:0]  hdmi_g          ,
    output var logic [8-1:0]  hdmi_b          ,
    output var logic          hdmi_hsync      ,
    output var logic          hdmi_vsync      ,
    output var logic          hdmi_de         ,
    output var logic [10-1:0] video_x         ,
    output var logic [10-1:0] video_y     
);
    localparam int unsigned          FB_WIDTH           = 256;
    localparam int unsigned          FB_HEIGHT          = 240;
    localparam int unsigned          FB_PIXELS          = FB_WIDTH * FB_HEIGHT;
    localparam logic        [10-1:0] H_ACTIVE           = 10'd720;
    localparam logic        [10-1:0] H_FRONT_PORCH      = 10'd16;
    localparam logic        [10-1:0] H_SYNC             = 10'd62;
    localparam logic        [10-1:0] H_TOTAL            = 10'd858;
    localparam logic        [10-1:0] V_ACTIVE           = 10'd480;
    localparam logic        [10-1:0] V_FRONT_PORCH      = 10'd9;
    localparam logic        [10-1:0] V_SYNC             = 10'd6;
    localparam logic        [10-1:0] V_TOTAL            = 10'd525;
    localparam logic        [10-1:0] X_OFFSET           = 10'd104;
    localparam logic        [10-1:0] SCALED_WIDTH       = 10'd512;
    localparam logic        [6-1:0]  BORDER_COLOR_INDEX = 6'd1;
    localparam logic        [24-1:0] BORDER_RGB         = 24'h003DA6;

    logic [6-1:0] framebuffer [FB_PIXELS];

    localparam logic [24-1:0] NES_PALETTE [64] = '{
        24'h808080, 24'h003DA6, 24'h0012B0, 24'h440096, 24'hA1005E, 24'hC70028, 24'hBA0600, 24'h8C1700, 24'h5C2F00,
        24'h104500, 24'h054A00, 24'h00472E, 24'h004166, 24'h000000, 24'h050505, 24'h050505, 24'hC7C7C7, 24'h0077FF,
        24'h2155FF, 24'h8237FA, 24'hEB2FB5, 24'hFF2950, 24'hFF2200, 24'hD63200, 24'hC46200, 24'h358000, 24'h058F00,
        24'h008A55, 24'h0099CC, 24'h212121, 24'h090909, 24'h090909, 24'hFFFFFF, 24'h0FD7FF, 24'h69A2FF, 24'hD480FF,
        24'hFF45F3, 24'hFF618B, 24'hFF8833, 24'hFF9C12, 24'hFABC20, 24'h9FE30E, 24'h2BF035, 24'h0CF0A4, 24'h05FBFF,
        24'h5E5E5E, 24'h0D0D0D, 24'h0D0D0D, 24'hFFFFFF, 24'hA6FCFF, 24'hB3ECFF, 24'hDAABEB, 24'hFFA8F9, 24'hFFABB3,
        24'hFFD2B0, 24'hFFEFA6, 24'hFFF79C, 24'hD7E895, 24'hA6EDAF, 24'hA2F2DA, 24'h99FFFC, 24'hDDDDDD, 24'h111111,
        24'h111111
    };

    logic          core_visible  ;
    logic [16-1:0] write_addr    ;
    logic [10-1:0] h_count       ;
    logic [10-1:0] v_count       ;
    logic [16-1:0] read_addr     ;
    logic [6-1:0]  read_pixel    ;
    logic [24-1:0] read_rgb      ;
    logic          read_de       ;
    logic          read_border   ;
    logic [10-1:0] read_x        ;
    logic [10-1:0] read_y        ;
    logic          active_area   ;
    logic          scaled_area   ;
    logic [10-1:0] scaled_x      ;
    logic [8-1:0]  src_x         ;
    logic [8-1:0]  src_y         ;
    logic [16-1:0] next_read_addr;

    always_comb core_visible   = core_cycle < 9'd256 && core_scanline < 9'd240;
    always_comb write_addr     = {core_scanline[7:0], 8'b0} + {8'b0, core_cycle[7:0]};
    always_comb active_area    = h_count < H_ACTIVE && v_count < V_ACTIVE;
    always_comb scaled_area    = active_area && h_count >= X_OFFSET && h_count < X_OFFSET + SCALED_WIDTH;
    always_comb scaled_x       = h_count - X_OFFSET;
    always_comb src_x          = scaled_x[8:1];
    always_comb src_y          = v_count[8:1];
    always_comb next_read_addr = {src_y, 8'b0} + {8'b0, src_x};
    always_comb read_rgb       = NES_PALETTE[read_pixel];

    always_ff @ (posedge clk) begin
        if (core_visible) begin
            framebuffer[write_addr] <= core_pixel_index;
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst) begin
            h_count     <= 0;
            v_count     <= 0;
            read_addr   <= 0;
            read_pixel  <= 0;
            read_de     <= 0;
            read_border <= 0;
            read_x      <= 0;
            read_y      <= 0;
            hdmi_r      <= 0;
            hdmi_g      <= 0;
            hdmi_b      <= 0;
            hdmi_hsync  <= 1;
            hdmi_vsync  <= 1;
            hdmi_de     <= 0;
            video_x     <= 0;
            video_y     <= 0;
        end else begin
            if (h_count == H_TOTAL - 10'd1) begin
                h_count <= 0;
                if (v_count == V_TOTAL - 10'd1) begin
                    v_count <= 0;
                end else begin
                    v_count <= v_count + 1;
                end
            end else begin
                h_count <= h_count + 1;
            end

            read_addr   <= ((scaled_area) ? ( next_read_addr ) : ( 16'd0 ));
            read_pixel  <= ((scaled_area) ? ( framebuffer[read_addr] ) : ( BORDER_COLOR_INDEX ));
            read_de     <= active_area;
            read_border <= active_area && !scaled_area;
            read_x      <= h_count;
            read_y      <= v_count;

            if (read_de) begin
                hdmi_r <= ((read_border) ? ( BORDER_RGB[23:16] ) : ( read_rgb[23:16] ));
                hdmi_g <= ((read_border) ? ( BORDER_RGB[15:8] ) : ( read_rgb[15:8] ));
                hdmi_b <= ((read_border) ? ( BORDER_RGB[7:0] ) : ( read_rgb[7:0] ));
            end else begin
                hdmi_r <= 8'd0;
                hdmi_g <= 8'd0;
                hdmi_b <= 8'd0;
            end

            hdmi_de    <= read_de;
            video_x    <= read_x;
            video_y    <= read_y;
            hdmi_hsync <= !(h_count >= H_ACTIVE + H_FRONT_PORCH && h_count < H_ACTIVE + H_FRONT_PORCH + H_SYNC);
            hdmi_vsync <= !(v_count >= V_ACTIVE + V_FRONT_PORCH && v_count < V_ACTIVE + V_FRONT_PORCH + V_SYNC);
        end
    end
endmodule
//# sourceMappingURL=hdmi_480p_scaler.sv.map
