module tarunes_ppu (
    input var logic                              clk                     ,
    input var logic                              rst                     ,
    input var logic                              frame_sync              ,
    tarunes___bus_if__8__3.slave           cpubus                  ,
    tarunes___bus_if__8__14.master         ppubus                  ,
    output var logic                      [9-1:0] scanline                ,
    output var logic                      [9-1:0] cycle                   ,
    output var logic                      [6-1:0] pixel_index             ,
    output var logic                              nmi                     ,
    output var logic                              frame_wait              ,
    output var logic                      [8-1:0] debug_palette0          ,
    output var logic                      [8-1:0] debug_palette1          ,
    output var logic                      [8-1:0] debug_palette2          ,
    output var logic                      [8-1:0] debug_palette3          ,
    output var logic                      [5-1:0] debug_bg_palette_addr   ,
    output var logic                      [8-1:0] debug_bg_palette_data   ,
    output var logic                              debug_palette_write     ,
    output var logic                      [5-1:0] debug_palette_write_addr,
    output var logic                      [8-1:0] debug_palette_write_data
) /*synthesis syn_ramstyle="registers"*/ ;
    typedef struct packed {
        logic         nmi_enable              ;
        logic         master_slave            ;
        logic         sprite_size             ;
        logic         background_pattern_table;
        logic         sprite_pattern_table    ;
        logic         vram_increment          ;
        logic [2-1:0] base_nametable          ;
    } ppu_ctrl_t;

    typedef struct packed {
        logic emphasize_blue      ;
        logic emphasize_green     ;
        logic emphasize_red       ;
        logic show_sprites        ;
        logic show_background     ;
        logic show_sprites_left   ;
        logic show_background_left;
        logic greyscale           ;
    } ppu_mask_t;

    typedef struct packed {
        logic         vblank         ;
        logic         sprite0_hit    ;
        logic         sprite_overflow;
        logic [5-1:0] open_bus       ;
    } ppu_status_t;

    typedef struct packed {
        logic [8-1:0] y   ;
        logic [8-1:0] tile;
        logic [8-1:0] attr;
        logic [8-1:0] x   ;
    } oam_t;

    localparam logic [3-1:0] PPUCTRL_ADDR   = 3'd0;
    localparam logic [3-1:0] PPUMASK_ADDR   = 3'd1;
    localparam logic [3-1:0] PPUSTATUS_ADDR = 3'd2;
    localparam logic [3-1:0] OAMADDR_ADDR   = 3'd3;
    localparam logic [3-1:0] OAMDATA_ADDR   = 3'd4;
    localparam logic [3-1:0] PPUSCROLL_ADDR = 3'd5;
    localparam logic [3-1:0] PPUADDR_ADDR   = 3'd6;
    localparam logic [3-1:0] PPUDATA_ADDR   = 3'd7;

    // VRAM Address Latch
    ppu_ctrl_t            reg_ctrl     ;
    ppu_mask_t            reg_mask     ;
    ppu_status_t          reg_status   ;
    logic                 reg_w        ;
    logic        [16-1:0] reg_v        ;
    logic        [16-1:0] reg_t        ;
    logic        [8-1:0]  reg_oam_addr ;
    logic        [3-1:0]  fine_x_scroll;

    // Gowinで小さいパレットRAMをRAM16系に推論させず、simに近いregister実装に固定する。
    // FPGAの未初期化値で背景色が固定されないよう、reset時は既知の黒系色にする。
    logic [8-1:0] palette_ram        [32];
    oam_t         oam                [64];
    logic         sprite_zero_hit        ;
    logic [8-1:0] ppu_data_buffer        ;
    logic [2-1:0] ppu_data_read_wait     ;

    // ppubus.address mux
    logic [14-1:0] ppu_addr_cpu   ;
    logic [14-1:0] ppu_addr_render;

    // パレット背景色 $3F10/$14/$18/$1C は $3F00/$04/$08/$0C のミラー。
    function automatic logic [5-1:0] palette_addr(
        input var logic [5-1:0] addr
    ) ;
        if ((addr == 5'h10 || addr == 5'h14 || addr == 5'h18 || addr == 5'h1C)) begin
            return addr - 5'h10;
        end else begin
            return addr;
        end
    endfunction

    function automatic logic is_palette_addr(
        input var logic [16-1:0] addr
    ) ;
        return addr[15:8] == 8'h3F;
    endfunction

    function automatic logic [14-1:0] bg_nt_addr(
        input var logic [16-1:0] v
    ) ;
        return 14'h2000 + v[11:0];
    endfunction

    function automatic logic [14-1:0] bg_attr_addr(
        input var logic [16-1:0] v
    ) ;
        return 14'h23C0 + {2'b00, v[11:10], 10'h000} + {5'b00000, v[9:7], 3'b000} + {7'b0000000, v[4:2]};
    endfunction

    function automatic logic [16-1:0] increment_bg_x(
        input var logic [16-1:0] v
    ) ;
        logic [16-1:0] ret;
        ret = v;
        if ((ret[4:0] == 5'd31)) begin
            ret[4:0] = 0;
            ret[10]  = ~ret[10];
        end else begin
            ret[4:0] = ret[4:0] + 1;
        end
        return ret;
    endfunction

    function automatic logic [16-1:0] increment_bg_y(
        input var logic [16-1:0] v
    ) ;
        logic [16-1:0] ret;
        ret = v;
        if ((ret[14:12] != 3'd7)) begin
            ret[14:12] = ret[14:12] + 1;
        end else begin
            ret[14:12] = 0;
            if ((ret[9:5] == 5'd29)) begin
                ret[9:5] = 0;
                ret[11]  = ~ret[11];
            end else if ((ret[9:5] == 5'd31)) begin
                ret[9:5] = 0;
            end else begin
                ret[9:5] = ret[9:5] + 1;
            end
        end
        return ret;
    endfunction

    always_comb begin
        ppubus.addr  = ppu_addr_render;
        ppubus.wen   = 0;
        ppubus.wdata = 0;

        if ((ppu_data_read_wait != 0)) begin
            ppubus.addr = ppu_addr_cpu;
        end

        if ((cpubus.wen && cpubus.addr == PPUDATA_ADDR && !is_palette_addr(reg_v))) begin
            ppubus.addr  = reg_v[13:0];
            ppubus.wen   = 1;
            ppubus.wdata = cpubus.wdata;
        end
    end

    // register bus
    always_ff @ (posedge clk) begin
        if (!rst) begin
            ppu_addr_cpu       <= 0;
            cpubus.rdata       <= 0;
            reg_ctrl           <= 0;
            reg_mask           <= 0;
            reg_status         <= 0;
            reg_w              <= 0;
            reg_v              <= 0;
            reg_t              <= 0;
            fine_x_scroll      <= 0;
            reg_oam_addr       <= 0;
            palette_ram        <= '{default: 8'h00};
            oam                <= '{default: 0};
            ppu_data_buffer    <= 0;
            ppu_data_read_wait <= 0;
        end else if (!frame_wait) begin
            if ((ppu_data_read_wait != 0)) begin
                if ((ppu_data_read_wait == 1)) begin
                    ppu_data_buffer    <= ppubus.rdata;
                    ppu_data_read_wait <= 0;
                end else begin
                    ppu_data_read_wait <= ppu_data_read_wait - 1;
                end
            end

            if ((scanline == 241 && cycle == 0)) begin
                reg_status.vblank <= 1;
            end else if ((scanline == 261 && cycle == 0)) begin
                reg_status.vblank      <= 0;
                reg_status.sprite0_hit <= 0;
            end else if ((sprite_zero_hit)) begin
                reg_status.sprite0_hit <= 1;
            end

            if ((cpubus.wen)) begin
                case ((cpubus.addr)) inside
                    PPUCTRL_ADDR: begin
                        reg_ctrl     <= cpubus.wdata;
                        reg_t[11:10] <= cpubus.wdata[1:0];
                    end

                    PPUMASK_ADDR: begin
                        reg_mask <= cpubus.wdata;
                    end

                    OAMADDR_ADDR: begin
                        reg_oam_addr <= cpubus.wdata;
                    end

                    OAMDATA_ADDR: begin
                        case ((reg_oam_addr[1:0]))
                            0: begin
                                oam[reg_oam_addr[7:2]].y <= cpubus.wdata;
                            end
                            1: begin
                                oam[reg_oam_addr[7:2]].tile <= cpubus.wdata;
                            end
                            2: begin
                                oam[reg_oam_addr[7:2]].attr <= cpubus.wdata;
                            end
                            default: begin
                                oam[reg_oam_addr[7:2]].x <= cpubus.wdata;
                            end
                        endcase
                        reg_oam_addr <= reg_oam_addr + 1;
                    end

                    PPUSCROLL_ADDR: begin
                        if ((!reg_w)) begin
                            reg_t[4:0]    <= cpubus.wdata[7:3];
                            fine_x_scroll <= cpubus.wdata[2:0];
                        end else begin
                            reg_t[9:5]   <= cpubus.wdata[7:3];
                            reg_t[14:12] <= cpubus.wdata[2:0];
                        end
                        reg_w <= ~reg_w;
                    end

                    PPUADDR_ADDR: begin
                        if ((!reg_w)) begin
                            reg_t[14:8] <= {1'b0, cpubus.wdata[5:0]};
                        end else begin
                            reg_t[7:0] <= cpubus.wdata;
                            reg_v      <= {reg_t[15:8], cpubus.wdata};
                        end
                        reg_w <= ~reg_w;
                    end

                    PPUDATA_ADDR: begin
                        // Palette RAM
                        if ((is_palette_addr(reg_v))) begin
                            palette_ram[palette_addr(reg_v[4:0])] <= cpubus.wdata;
                        end
                        reg_v <= reg_v + (((reg_ctrl.vram_increment) ? ( 32 ) : ( 1 )));
                    end
                endcase
            end else begin
                case ((cpubus.addr)) inside
                    PPUSTATUS_ADDR: begin
                        cpubus.rdata      <= reg_status;
                        reg_status.vblank <= 0;
                        reg_w             <= 0;
                    end
                    OAMDATA_ADDR: begin
                        case ((reg_oam_addr[1:0]))
                            0: begin
                                cpubus.rdata <= oam[reg_oam_addr[7:2]].y;
                            end
                            1: begin
                                cpubus.rdata <= oam[reg_oam_addr[7:2]].tile;
                            end
                            2: begin
                                cpubus.rdata <= oam[reg_oam_addr[7:2]].attr;
                            end
                            default: begin
                                cpubus.rdata <= oam[reg_oam_addr[7:2]].x;
                            end
                        endcase
                    end
                    PPUDATA_ADDR: begin
                        if ((is_palette_addr(reg_v))) begin
                            cpubus.rdata <= palette_ram[palette_addr(reg_v[4:0])];
                        end else begin
                            cpubus.rdata       <= ppu_data_buffer;
                            ppu_addr_cpu       <= reg_v[13:0];
                            ppu_data_read_wait <= 2;
                        end

                        reg_v <= reg_v + (((reg_ctrl.vram_increment) ? ( 32 ) : ( 1 )));
                    end
                    default: begin
                        cpubus.rdata <= 0;
                    end
                endcase
            end

            if (((reg_mask.show_background || reg_mask.show_sprites) && (scanline < 240 || scanline == 261))) begin
                if ((cycle == 255)) begin
                    reg_v <= increment_bg_y(increment_bg_x(reg_v));
                end else if (((cycle < 256 || (cycle >= 320 && cycle < 336)) && cycle[2:0] == 7)) begin
                    reg_v <= increment_bg_x(reg_v);
                end else if ((cycle == 256)) begin
                    reg_v[10]  <= reg_t[10];
                    reg_v[4:0] <= reg_t[4:0];
                end else if ((scanline == 261 && cycle >= 280 && cycle < 305)) begin
                    reg_v[14:11] <= reg_t[14:11];
                    reg_v[9:5]   <= reg_t[9:5];
                end
            end
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst) begin
            cycle      <= 0;
            scanline   <= 0;
            nmi        <= 0;
            frame_wait <= 0;
        end else if (frame_wait) begin
            nmi <= 0;
            if (frame_sync) begin
                cycle      <= 0;
                scanline   <= 0;
                frame_wait <= 0;
            end
        end else begin
            if ((scanline == 241 && cycle == 0 && reg_ctrl.nmi_enable)) begin
                nmi <= 1;
            end else begin
                nmi <= 0;
            end

            if ((cycle == 340)) begin
                if ((scanline == 261)) begin
                    frame_wait <= 1;
                end else begin
                    cycle    <= 0;
                    scanline <= scanline + 1;
                end
            end else begin
                cycle <= cycle + 1;
            end
        end
    end

    logic visible;
    always_comb visible = cycle < 256 && scanline < 240;

    logic [9-1:0] sprite_eval_line;
    always_comb sprite_eval_line = (((scanline == 261)) ? ( 0 ) : ( scanline + 1 ));

    // キャラクタROMのアドレス
    logic [14-1:0] chr_addr;

    logic rendering_enabled;
    always_comb rendering_enabled = reg_mask.show_background || reg_mask.show_sprites;

    logic bg_fetch_active;
    always_comb bg_fetch_active = rendering_enabled && (scanline < 240 || scanline == 261)
        && (cycle < 256 || (cycle >= 320 && cycle < 336));

    // Background fetch latches and shifters
    logic [8-1:0]  bg_attr_byte         ;
    logic [8-1:0]  bg_pattern_low_latch ;
    logic [8-1:0]  bg_pattern_high_latch;
    logic [2-1:0]  bg_palette_latch     ;
    logic [16-1:0] bg_pattern_shift_low ;
    logic [16-1:0] bg_pattern_shift_high;
    logic [16-1:0] bg_attr_shift_low    ;
    logic [16-1:0] bg_attr_shift_high   ;

    // Sprite fetch buffer for the next visible scanline
    logic         sprite_valid        [8];
    logic [8-1:0] sprite_x            [8];
    logic [8-1:0] sprite_tile         [8];
    logic [8-1:0] sprite_attr         [8];
    logic [3-1:0] sprite_row          [8];
    logic [8-1:0] sprite_pattern_low  [8];
    logic [8-1:0] sprite_pattern_high [8];
    logic         sprite_is_zero      [8];
    logic [4-1:0] sprite_eval_count      ;
    logic         eval_sprite_valid   [8];
    logic [8-1:0] eval_sprite_x       [8];
    logic [8-1:0] eval_sprite_tile    [8];
    logic [8-1:0] eval_sprite_attr    [8];
    logic [3-1:0] eval_sprite_row     [8];
    logic         eval_sprite_is_zero [8];
    logic [4-1:0] eval_sprite_count      ;

    function automatic logic sprite_on_line(
        input var logic [9-1:0] line ,
        input var logic [8-1:0] raw_y
    ) ;
        logic [9-1:0] sprite_top;
        logic [9-1:0] sprite_end;
        sprite_top = {1'b0, raw_y} + 1;
        sprite_end = sprite_top + 8;
        return line >= sprite_top && line < sprite_end;
    endfunction

    function automatic logic [3-1:0] sprite_line_row(
        input var logic [9-1:0] line ,
        input var logic [8-1:0] raw_y,
        input var logic [8-1:0] attr 
    ) ;
        logic [9-1:0] sprite_top;
        logic [3-1:0] raw_row   ;
        sprite_top = {1'b0, raw_y} + 1;
        raw_row    = line[2:0] - sprite_top[2:0];
        return ((attr[7]) ? ( 7 - raw_row ) : ( raw_row ));
    endfunction

    // VRAMとキャラクタROMからデータを取ってくる
    always_ff @ (posedge clk) begin
        if (!rst) begin
            ppu_addr_render       <= 0;
            chr_addr              <= 0;
            bg_attr_byte          <= 0;
            bg_pattern_low_latch  <= 0;
            bg_pattern_high_latch <= 0;
            bg_palette_latch      <= 0;
            bg_pattern_shift_low  <= 0;
            bg_pattern_shift_high <= 0;
            bg_attr_shift_low     <= 0;
            bg_attr_shift_high    <= 0;
            sprite_valid          <= '{default: 0};
            sprite_x              <= '{default: 0};
            sprite_tile           <= '{default: 0};
            sprite_attr           <= '{default: 0};
            sprite_row            <= '{default: 0};
            sprite_pattern_low    <= '{default: 0};
            sprite_pattern_high   <= '{default: 0};
            sprite_is_zero        <= '{default: 0};
            sprite_eval_count     <= 0;
            eval_sprite_valid     <= '{default: 0};
            eval_sprite_x         <= '{default: 0};
            eval_sprite_tile      <= '{default: 0};
            eval_sprite_attr      <= '{default: 0};
            eval_sprite_row       <= '{default: 0};
            eval_sprite_is_zero   <= '{default: 0};
            eval_sprite_count     <= 0;
        end else if (!frame_wait) begin
            if ((bg_fetch_active)) begin
                if ((cycle[2:0] != 7)) begin
                    bg_pattern_shift_low  <= {bg_pattern_shift_low[14:0], 1'b0};
                    bg_pattern_shift_high <= {bg_pattern_shift_high[14:0], 1'b0};
                    bg_attr_shift_low     <= {bg_attr_shift_low[14:0], 1'b0};
                    bg_attr_shift_high    <= {bg_attr_shift_high[14:0], 1'b0};
                end

                case ((cycle[2:0]))
                    0: begin
                        ppu_addr_render <= bg_nt_addr(reg_v);
                    end
                    1: begin
                        ppu_addr_render <= bg_attr_addr(reg_v);
                    end
                    2: begin
                        logic [8-1:0]  tile_id        ;
                        logic [14-1:0] bg_pattern_base;
                        tile_id         = ppubus.rdata;
                        bg_pattern_base = ((reg_ctrl.background_pattern_table) ? ( 14'h1000 ) : ( 14'h0000 ));
                        ppu_addr_render <= bg_pattern_base + tile_id * 16 + reg_v[14:12];
                        chr_addr        <= bg_pattern_base + tile_id * 16 + reg_v[14:12];
                    end
                    3: begin
                        bg_attr_byte    <= ppubus.rdata;
                        ppu_addr_render <= chr_addr + 8;
                    end
                    4: begin
                        bg_pattern_low_latch <= ppubus.rdata;
                        case (({reg_v[6], reg_v[1]}))
                            2'b00: begin
                                bg_palette_latch <= bg_attr_byte[1:0];
                            end
                            2'b01: begin
                                bg_palette_latch <= bg_attr_byte[3:2];
                            end
                            2'b10: begin
                                bg_palette_latch <= bg_attr_byte[5:4];
                            end
                            default: begin
                                bg_palette_latch <= bg_attr_byte[7:6];
                            end
                        endcase
                    end
                    5: begin
                        bg_pattern_high_latch <= ppubus.rdata;
                    end
                    7: begin
                        bg_pattern_shift_low  <= {bg_pattern_shift_low[14:7], bg_pattern_low_latch};
                        bg_pattern_shift_high <= {bg_pattern_shift_high[14:7], bg_pattern_high_latch};
                        bg_attr_shift_low     <= {bg_attr_shift_low[14:7], {8{bg_palette_latch[0]}}};
                        bg_attr_shift_high    <= {bg_attr_shift_high[14:7], {8{bg_palette_latch[1]}}};
                    end
                endcase
            end

            if ((visible)) begin
                if ((cycle == 0)) begin
                    eval_sprite_valid   <= '{default: 0};
                    eval_sprite_x       <= '{default: 0};
                    eval_sprite_tile    <= '{default: 0};
                    eval_sprite_attr    <= '{default: 0};
                    eval_sprite_row     <= '{default: 0};
                    eval_sprite_is_zero <= '{default: 0};
                    eval_sprite_count   <= 0;
                end

                if ((cycle < 64 && sprite_eval_line < 240)) begin
                    logic [6-1:0] oam_index      ;
                    logic [8-1:0] sprite_oam_y   ;
                    logic [8-1:0] sprite_oam_attr;
                    oam_index       = cycle[5:0];
                    sprite_oam_y    = oam[oam_index].y;
                    sprite_oam_attr = oam[oam_index].attr;

                    if ((eval_sprite_count < 8 && sprite_on_line(sprite_eval_line, sprite_oam_y))) begin
                        eval_sprite_valid[eval_sprite_count[2:0]] <= 1;
                        eval_sprite_x[eval_sprite_count[2:0]]     <= oam[oam_index].x;
                        eval_sprite_tile[eval_sprite_count[2:0]]  <= oam[oam_index].tile;
                        eval_sprite_attr[eval_sprite_count[2:0]]  <= sprite_oam_attr;
                        eval_sprite_row[eval_sprite_count[2:0]]   <= sprite_line_row(
                            sprite_eval_line,
                            sprite_oam_y,
                            sprite_oam_attr
                        );
                        eval_sprite_is_zero[eval_sprite_count[2:0]] <= oam_index == 0;
                        eval_sprite_count                           <= eval_sprite_count + 1;
                    end
                end

            end else if ((cycle == 256)) begin
                sprite_valid        <= '{default: 0};
                sprite_x            <= '{default: 0};
                sprite_tile         <= '{default: 0};
                sprite_attr         <= '{default: 0};
                sprite_row          <= '{default: 0};
                sprite_pattern_low  <= '{default: 0};
                sprite_pattern_high <= '{default: 0};
                sprite_is_zero      <= '{default: 0};
                sprite_eval_count   <= 0;
                sprite_valid        <= eval_sprite_valid;
                sprite_x            <= eval_sprite_x;
                sprite_tile         <= eval_sprite_tile;
                sprite_attr         <= eval_sprite_attr;
                sprite_row          <= eval_sprite_row;
                sprite_is_zero      <= eval_sprite_is_zero;
                sprite_eval_count   <= eval_sprite_count;
            end else if ((cycle >= 257 && cycle < 289)) begin
                logic [9-1:0]  sprite_fetch_cycle ;
                logic [3-1:0]  sprite_fetch_slot  ;
                logic [2-1:0]  sprite_fetch_phase ;
                logic [14-1:0] sprite_pattern_base;
                logic [14-1:0] sprite_chr_addr    ;
                sprite_fetch_cycle  = cycle - 257;
                sprite_fetch_slot   = sprite_fetch_cycle[4:2];
                sprite_fetch_phase  = sprite_fetch_cycle[1:0];
                sprite_pattern_base = ((reg_ctrl.sprite_pattern_table) ? ( 14'h1000 ) : ( 14'h0000 ));
                sprite_chr_addr     = sprite_pattern_base + sprite_tile[sprite_fetch_slot] * 16
                    + sprite_row[sprite_fetch_slot];

                case ((sprite_fetch_phase))
                    0: begin
                        ppu_addr_render <= sprite_chr_addr;
                    end
                    1: begin
                        ppu_addr_render <= sprite_chr_addr + 8;
                    end
                    2: begin
                        sprite_pattern_low[sprite_fetch_slot] <= ppubus.rdata;
                    end
                    3: begin
                        sprite_pattern_high[sprite_fetch_slot] <= ppubus.rdata;
                    end
                endcase
            end
        end
    end

    logic [2-1:0] color_2bit           ;
    logic [4-1:0] fine_x               ;
    logic [2-1:0] bg_palette_select    ;
    logic         bg_visible           ;
    logic         bg_pixel_visible     ;
    logic         sprite_visible       ;
    logic         sprite_pixel_visible ;
    logic         sprite_priority_back ;
    logic [2-1:0] sprite_color_2bit    ;
    logic [2-1:0] sprite_palette_select;
    logic         sprite_zero_pixel    ;
    logic [5-1:0] bg_palette_addr      ;

    always_comb bg_palette_addr          = {1'b0, bg_palette_select, color_2bit};
    always_comb debug_palette0           = palette_ram[0];
    always_comb debug_palette1           = palette_ram[1];
    always_comb debug_palette2           = palette_ram[2];
    always_comb debug_palette3           = palette_ram[3];
    always_comb debug_bg_palette_addr    = bg_palette_addr;
    always_comb debug_bg_palette_data    = palette_ram[bg_palette_addr];
    always_comb debug_palette_write      = cpubus.wen && cpubus.addr == PPUDATA_ADDR && is_palette_addr(reg_v);
    always_comb debug_palette_write_addr = palette_addr(reg_v[4:0]);
    always_comb debug_palette_write_data = cpubus.wdata;

    always_comb fine_x            = 4'd15 - {1'b0, fine_x_scroll};
    always_comb color_2bit        = {bg_pattern_shift_high[fine_x], bg_pattern_shift_low[fine_x]};
    always_comb bg_palette_select = {bg_attr_shift_high[fine_x], bg_attr_shift_low[fine_x]};
    always_comb bg_visible        = reg_mask.show_background && (reg_mask.show_background_left || !(cycle < 8));
    always_comb bg_pixel_visible  = bg_visible && color_2bit != 0;
    always_comb sprite_visible    = reg_mask.show_sprites && (reg_mask.show_sprites_left || !(cycle < 8));
    // SMB waits for sprite0 hit before changing scroll mid-frame.  This PPU's
    // background fetch is simplified, so tying the hit to the exact fetched
    // background pixel can miss the split point during horizontal scroll.
    always_comb sprite_zero_hit = visible && bg_visible && sprite_zero_pixel;

    always_comb begin
        sprite_pixel_visible  = 0;
        sprite_priority_back  = 0;
        sprite_color_2bit     = 0;
        sprite_palette_select = 0;
        sprite_zero_pixel     = 0;

        for (int i = 0; i < 8; i++) begin
            logic [9-1:0] sprite_right ;
            logic [3-1:0] sprite_offset;
            logic [3-1:0] sprite_bit   ;
            logic [2-1:0] sprite_color ;
            sprite_right  = {1'b0, sprite_x[i]} + 8;
            sprite_offset = cycle[2:0] - sprite_x[i][2:0];
            sprite_bit    = ((sprite_attr[i][6]) ? ( sprite_offset ) : ( 7 - sprite_offset ));
            sprite_color  = {sprite_pattern_high[i][sprite_bit], sprite_pattern_low[i][sprite_bit]};

            if ((visible && sprite_visible && !sprite_pixel_visible && sprite_valid[i] && cycle >= {1'b0, sprite_x[i]}
                && cycle < sprite_right)) begin
                if ((sprite_color != 0)) begin
                    sprite_pixel_visible  = 1;
                    sprite_priority_back  = sprite_attr[i][5];
                    sprite_color_2bit     = sprite_color;
                    sprite_palette_select = sprite_attr[i][1:0];
                    sprite_zero_pixel     = sprite_is_zero[i];
                end
            end
        end
    end

    always_comb begin
        if ((cycle < 256 && scanline < 240)) begin
            if ((sprite_pixel_visible && (!sprite_priority_back || !bg_pixel_visible))) begin
                pixel_index = palette_ram[{1'b1, sprite_palette_select, sprite_color_2bit}][5:0];
            end else if ((bg_pixel_visible)) begin
                pixel_index = palette_ram[bg_palette_addr][5:0];
            end else begin
                pixel_index = palette_ram[5'd0][5:0];
            end
        end else begin
            pixel_index = 6'h0F;
        end
    end
endmodule
//# sourceMappingURL=ppu.sv.map
