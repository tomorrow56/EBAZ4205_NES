module tarunes_apu (
    input var logic                            clk         ,
    input var logic                            rst         ,
    input var logic                            stall       ,
    input var logic                            bus_stall   ,
    tarunes___bus_if__8__5.slave         cpubus      ,
    output var logic                    [8-1:0] audio_sample
);
    typedef struct packed {
        logic [2-1:0] duty               ;
        logic         length_counter_halt;
        logic         constant_volume    ;
        logic [4-1:0] volume             ;
    } pulse_ctrl_t;

    typedef struct packed {
        logic         enabled;
        logic [3-1:0] period ;
        logic         negate ;
        logic [3-1:0] shift  ;
    } sweep_t;

    typedef struct packed {
        logic         control;
        logic [7-1:0] reload ;
    } triangle_linear_t;

    typedef struct packed {
        logic [2-1:0] unused             ;
        logic         length_counter_halt;
        logic         constant_volume    ;
        logic [4-1:0] volume             ;
    } noise_ctrl_t;

    typedef struct packed {
        logic         mode  ;
        logic [3-1:0] unused;
        logic [4-1:0] period;
    } noise_period_t;

    localparam logic [5-1:0] PULSE1_CTRL_ADDR       = 5'h00;
    localparam logic [5-1:0] PULSE1_SWEEP_ADDR      = 5'h01;
    localparam logic [5-1:0] PULSE1_TIMER_LO_ADDR   = 5'h02;
    localparam logic [5-1:0] PULSE1_TIMER_HI_ADDR   = 5'h03;
    localparam logic [5-1:0] PULSE2_CTRL_ADDR       = 5'h04;
    localparam logic [5-1:0] PULSE2_SWEEP_ADDR      = 5'h05;
    localparam logic [5-1:0] PULSE2_TIMER_LO_ADDR   = 5'h06;
    localparam logic [5-1:0] PULSE2_TIMER_HI_ADDR   = 5'h07;
    localparam logic [5-1:0] TRIANGLE_LINEAR_ADDR   = 5'h08;
    localparam logic [5-1:0] TRIANGLE_TIMER_LO_ADDR = 5'h0A;
    localparam logic [5-1:0] TRIANGLE_TIMER_HI_ADDR = 5'h0B;
    localparam logic [5-1:0] NOISE_CTRL_ADDR        = 5'h0C;
    localparam logic [5-1:0] NOISE_PERIOD_ADDR      = 5'h0E;
    localparam logic [5-1:0] NOISE_LENGTH_ADDR      = 5'h0F;
    localparam logic [5-1:0] STATUS_ADDR            = 5'h15;
    localparam logic [5-1:0] FRAME_COUNTER_ADDR     = 5'h17;

    localparam logic [15-1:0] FRAME_STEP_1 = 15'd3728;
    localparam logic [15-1:0] FRAME_STEP_2 = 15'd7456;
    localparam logic [15-1:0] FRAME_STEP_3 = 15'd11185;
    localparam logic [15-1:0] FRAME_STEP_4 = 15'd14914;
    localparam logic [15-1:0] FRAME_STEP_5 = 15'd18640;

    localparam logic [8-1:0] LENGTH_TABLE [32] = '{
        8'd10, 8'd254, 8'd20, 8'd2, 8'd40, 8'd4, 8'd80, 8'd6, 8'd160, 8'd8, 8'd60, 8'd10, 8'd14, 8'd12, 8'd26, 8'd14,
        8'd12, 8'd16, 8'd24, 8'd18, 8'd48, 8'd20, 8'd96, 8'd22, 8'd192, 8'd24, 8'd72, 8'd26, 8'd16, 8'd28, 8'd32, 8'd30
    };

    localparam logic [8-1:0] DUTY_TABLE     [4]  = '{8'b01000000, 8'b01100000, 8'b01111000, 8'b10011111};
    localparam logic [4-1:0] TRIANGLE_TABLE [32] = '{
        4'd15, 4'd14, 4'd13, 4'd12, 4'd11, 4'd10, 4'd9, 4'd8, 4'd7, 4'd6, 4'd5, 4'd4, 4'd3, 4'd2, 4'd1, 4'd0, 4'd0,
        4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9, 4'd10, 4'd11, 4'd12, 4'd13, 4'd14, 4'd15
    };
    localparam logic [12-1:0] NOISE_PERIOD_TABLE [16] = '{
        12'd4, 12'd8, 12'd16, 12'd32, 12'd64, 12'd96, 12'd128, 12'd160, 12'd202, 12'd254, 12'd380, 12'd508, 12'd762,
        12'd1016, 12'd2034, 12'd4068
    };
    localparam logic [7-1:0] PULSE_MIX_TABLE [31] = '{
        7'd0, 7'd2, 7'd5, 7'd7, 7'd9, 7'd11, 7'd13, 7'd15, 7'd17, 7'd19, 7'd21, 7'd23, 7'd25, 7'd26, 7'd28, 7'd30,
        7'd32, 7'd33, 7'd35, 7'd36, 7'd38, 7'd39, 7'd41, 7'd42, 7'd44, 7'd45, 7'd46, 7'd48, 7'd49, 7'd50, 7'd52
    };
    localparam logic [7-1:0] TND_MIX_TABLE [256] = '{
        7'd0, 7'd3, 7'd5, 7'd8, 7'd10, 7'd13, 7'd15, 7'd17, 7'd20, 7'd22, 7'd24, 7'd26, 7'd29, 7'd31, 7'd33, 7'd35,
        7'd4, 7'd6, 7'd9, 7'd11, 7'd14, 7'd16, 7'd18, 7'd21, 7'd23, 7'd25, 7'd27, 7'd30, 7'd32, 7'd34, 7'd36, 7'd38,
        7'd8, 7'd10, 7'd12, 7'd15, 7'd17, 7'd20, 7'd22, 7'd24, 7'd26, 7'd28, 7'd31, 7'd33, 7'd35, 7'd37, 7'd39, 7'd41,
        7'd11, 7'd14, 7'd16, 7'd18, 7'd21, 7'd23, 7'd25, 7'd27, 7'd30, 7'd32, 7'd34, 7'd36, 7'd38, 7'd40, 7'd42, 7'd44,
        7'd15, 7'd17, 7'd19, 7'd22, 7'd24, 7'd26, 7'd28, 7'd31, 7'd33, 7'd35, 7'd37, 7'd39, 7'd41, 7'd43, 7'd45, 7'd47,
        7'd18, 7'd21, 7'd23, 7'd25, 7'd27, 7'd29, 7'd32, 7'd34, 7'd36, 7'd38, 7'd40, 7'd42, 7'd44, 7'd46, 7'd48, 7'd50,
        7'd22, 7'd24, 7'd26, 7'd28, 7'd31, 7'd33, 7'd35, 7'd37, 7'd39, 7'd41, 7'd43, 7'd45, 7'd47, 7'd49, 7'd50, 7'd52,
        7'd25, 7'd27, 7'd29, 7'd32, 7'd34, 7'd36, 7'd38, 7'd40, 7'd42, 7'd44, 7'd46, 7'd48, 7'd49, 7'd51, 7'd53, 7'd55,
        7'd28, 7'd30, 7'd33, 7'd35, 7'd37, 7'd39, 7'd41, 7'd43, 7'd45, 7'd47, 7'd49, 7'd50, 7'd52, 7'd54, 7'd56, 7'd58,
        7'd32, 7'd34, 7'd36, 7'd38, 7'd40, 7'd42, 7'd44, 7'd46, 7'd48, 7'd49, 7'd51, 7'd53, 7'd55, 7'd57, 7'd58, 7'd60,
        7'd35, 7'd37, 7'd39, 7'd41, 7'd43, 7'd45, 7'd47, 7'd48, 7'd50, 7'd52, 7'd54, 7'd56, 7'd58, 7'd59, 7'd61, 7'd63,
        7'd38, 7'd40, 7'd42, 7'd44, 7'd46, 7'd47, 7'd49, 7'd51, 7'd53, 7'd55, 7'd57, 7'd58, 7'd60, 7'd62, 7'd64, 7'd65,
        7'd41, 7'd43, 7'd45, 7'd47, 7'd48, 7'd50, 7'd52, 7'd54, 7'd56, 7'd57, 7'd59, 7'd61, 7'd63, 7'd64, 7'd66, 7'd68,
        7'd44, 7'd46, 7'd47, 7'd49, 7'd51, 7'd53, 7'd55, 7'd57, 7'd58, 7'd60, 7'd62, 7'd63, 7'd65, 7'd67, 7'd68, 7'd70,
        7'd46, 7'd48, 7'd50, 7'd52, 7'd54, 7'd56, 7'd57, 7'd59, 7'd61, 7'd63, 7'd64, 7'd66, 7'd68, 7'd69, 7'd71, 7'd72,
        7'd49, 7'd51, 7'd53, 7'd55, 7'd57, 7'd58, 7'd60, 7'd62, 7'd63, 7'd65, 7'd67, 7'd68, 7'd70, 7'd72, 7'd73, 7'd75
    };

    pulse_ctrl_t          pulse1_reg_ctrl      ;
    sweep_t               pulse1_reg_sweep     ;
    logic        [11-1:0] pulse1_timer_period  ;
    logic        [11-1:0] pulse1_timer_counter ;
    logic        [3-1:0]  pulse1_sequencer     ;
    logic        [8-1:0]  pulse1_length_counter;
    logic                 pulse1_enabled       ;
    logic        [3-1:0]  pulse1_sweep_divider ;
    logic        [4-1:0]  pulse1_level         ;
    logic                 pulse1_duty_bit      ;
    logic        [4-1:0]  pulse1_volume        ;
    logic        [11-1:0] pulse1_sweep_shift   ;
    logic        [12-1:0] pulse1_sweep_target  ;
    logic                 pulse1_sweep_mute    ;
    logic                 pulse1_env_start     ;
    logic        [4-1:0]  pulse1_env_divider   ;
    logic        [4-1:0]  pulse1_env_decay     ;

    pulse_ctrl_t          pulse2_reg_ctrl      ;
    sweep_t               pulse2_reg_sweep     ;
    logic        [11-1:0] pulse2_timer_period  ;
    logic        [11-1:0] pulse2_timer_counter ;
    logic        [3-1:0]  pulse2_sequencer     ;
    logic        [8-1:0]  pulse2_length_counter;
    logic                 pulse2_enabled       ;
    logic        [3-1:0]  pulse2_sweep_divider ;
    logic        [4-1:0]  pulse2_level         ;
    logic                 pulse2_duty_bit      ;
    logic        [4-1:0]  pulse2_volume        ;
    logic        [11-1:0] pulse2_sweep_shift   ;
    logic        [12-1:0] pulse2_sweep_target  ;
    logic                 pulse2_sweep_mute    ;
    logic                 pulse2_env_start     ;
    logic        [4-1:0]  pulse2_env_divider   ;
    logic        [4-1:0]  pulse2_env_decay     ;

    triangle_linear_t          triangle_reg_linear        ;
    logic             [11-1:0] triangle_timer_period      ;
    logic             [11-1:0] triangle_timer_counter     ;
    logic             [5-1:0]  triangle_sequencer         ;
    logic             [8-1:0]  triangle_length_counter    ;
    logic             [7-1:0]  triangle_linear_counter    ;
    logic                      triangle_linear_reload_flag;
    logic                      triangle_enabled           ;
    logic             [4-1:0]  triangle_level             ;

    noise_ctrl_t            noise_reg_ctrl      ;
    noise_period_t          noise_reg_period    ;
    logic          [12-1:0] noise_timer_period  ;
    logic          [12-1:0] noise_timer_counter ;
    logic          [8-1:0]  noise_length_counter;
    logic          [15-1:0] noise_shift         ;
    logic                   noise_enabled       ;
    logic                   noise_feedback      ;
    logic          [4-1:0]  noise_volume        ;
    logic          [4-1:0]  noise_level         ;
    logic                   noise_env_start     ;
    logic          [4-1:0]  noise_env_divider   ;
    logic          [4-1:0]  noise_env_decay     ;

    logic [2-1:0]  apu_tick_div           ;
    logic          apu_half_tick          ;
    logic          frame_counter_mode     ;
    logic [15-1:0] frame_counter          ;
    logic          frame_counter_write    ;
    logic          frame_counter_mode_next;
    logic          frame_quarter_tick     ;
    logic          frame_half_tick        ;
    logic          frame_counter_last     ;
    logic          pulse1_sweep_write     ;
    logic          pulse1_timer_lo_write  ;
    logic          pulse1_timer_hi_write  ;
    logic [8-1:0]  pulse1_timer_lo_wdata  ;
    logic [8-1:0]  pulse1_timer_hi_wdata  ;
    logic          pulse2_sweep_write     ;
    logic          pulse2_timer_lo_write  ;
    logic          pulse2_timer_hi_write  ;
    logic [8-1:0]  pulse2_timer_lo_wdata  ;
    logic [8-1:0]  pulse2_timer_hi_wdata  ;
    logic          triangle_timer_lo_write;
    logic          triangle_timer_hi_write;
    logic [8-1:0]  triangle_timer_lo_wdata;
    logic [8-1:0]  triangle_timer_hi_wdata;
    logic          noise_length_write     ;
    logic [8-1:0]  noise_length_wdata     ;
    logic          status_write           ;
    logic [8-1:0]  status_wdata           ;
    logic [5-1:0]  pulse_mix_level        ;
    logic [8-1:0]  tnd_mix_index          ;
    logic [8-1:0]  audio_mix_level        ;

    always_comb pulse1_duty_bit     = DUTY_TABLE[pulse1_reg_ctrl.duty][pulse1_sequencer];
    always_comb pulse1_volume       = ((pulse1_reg_ctrl.constant_volume) ? (
        pulse1_reg_ctrl.volume
    ) : (
        pulse1_env_decay
    ));
    always_comb pulse1_sweep_shift  = pulse1_timer_period >> pulse1_reg_sweep.shift;
    always_comb pulse1_sweep_target = ((pulse1_reg_sweep.negate) ? (
        {1'b0, pulse1_timer_period} - {1'b0, pulse1_sweep_shift} - 12'd1
    ) : (
        {1'b0, pulse1_timer_period} + {1'b0, pulse1_sweep_shift}
    ));
    always_comb pulse1_sweep_mute = pulse1_timer_period < 8 || pulse1_sweep_target > 12'h7FF;
    always_comb pulse1_level      = ((pulse1_enabled && pulse1_length_counter != 0 && !pulse1_sweep_mute
        && pulse1_duty_bit) ? (
        pulse1_volume
    ) : (
        4'd0
    ));

    always_comb pulse2_duty_bit     = DUTY_TABLE[pulse2_reg_ctrl.duty][pulse2_sequencer];
    always_comb pulse2_volume       = ((pulse2_reg_ctrl.constant_volume) ? (
        pulse2_reg_ctrl.volume
    ) : (
        pulse2_env_decay
    ));
    always_comb pulse2_sweep_shift  = pulse2_timer_period >> pulse2_reg_sweep.shift;
    always_comb pulse2_sweep_target = ((pulse2_reg_sweep.negate) ? (
        {1'b0, pulse2_timer_period} - {1'b0, pulse2_sweep_shift}
    ) : (
        {1'b0, pulse2_timer_period} + {1'b0, pulse2_sweep_shift}
    ));
    always_comb pulse2_sweep_mute = pulse2_timer_period < 8 || pulse2_sweep_target > 12'h7FF;
    always_comb pulse2_level      = ((pulse2_enabled && pulse2_length_counter != 0 && !pulse2_sweep_mute
        && pulse2_duty_bit) ? (
        pulse2_volume
    ) : (
        4'd0
    ));

    always_comb triangle_level = ((triangle_enabled && triangle_length_counter != 0 && triangle_linear_counter != 0
        && triangle_timer_period >= 3) ? (
        TRIANGLE_TABLE[triangle_sequencer]
    ) : (
        4'd0
    ));

    always_comb noise_timer_period = NOISE_PERIOD_TABLE[noise_reg_period.period];
    always_comb noise_feedback     = noise_shift[0]
        ^ (((noise_reg_period.mode) ? ( noise_shift[6] ) : ( noise_shift[1] )));
    always_comb noise_volume       = ((noise_reg_ctrl.constant_volume) ? (
        noise_reg_ctrl.volume
    ) : (
        noise_env_decay
    ));
    always_comb noise_level        = ((noise_enabled && noise_length_counter != 0 && !noise_shift[0]) ? (
        noise_volume
    ) : (
        4'd0
    ));

    always_comb pulse_mix_level    = {1'b0, pulse1_level} + {1'b0, pulse2_level};
    always_comb tnd_mix_index      = {triangle_level, noise_level};
    always_comb audio_mix_level    = {1'b0, PULSE_MIX_TABLE[pulse_mix_level]} + {1'b0, TND_MIX_TABLE[tnd_mix_index]};
    always_comb audio_sample       = 8'h80 + audio_mix_level;
    always_comb frame_quarter_tick = (frame_counter_write && frame_counter_mode_next)
        || (apu_tick_div == 2
            && (frame_counter == FRAME_STEP_1 || frame_counter == FRAME_STEP_2 || frame_counter == FRAME_STEP_3
                || (((frame_counter_mode) ? ( frame_counter == FRAME_STEP_5 ) : ( frame_counter == FRAME_STEP_4 )))));
    always_comb frame_half_tick = (frame_counter_write && frame_counter_mode_next)
        || (apu_tick_div == 2
            && (frame_counter == FRAME_STEP_2
                || (((frame_counter_mode) ? ( frame_counter == FRAME_STEP_5 ) : ( frame_counter == FRAME_STEP_4 )))));
    always_comb frame_counter_last = ((frame_counter_mode) ? (
        frame_counter == FRAME_STEP_5
    ) : (
        frame_counter == FRAME_STEP_4
    ));

    always_ff @ (posedge clk) begin
        if (!rst) begin
            cpubus.rdata            <= 0;
            pulse1_reg_ctrl         <= 0;
            pulse1_reg_sweep        <= 0;
            pulse1_enabled          <= 0;
            pulse2_reg_ctrl         <= 0;
            pulse2_reg_sweep        <= 0;
            pulse2_enabled          <= 0;
            triangle_reg_linear     <= 0;
            triangle_enabled        <= 0;
            noise_reg_ctrl          <= 0;
            noise_reg_period        <= 0;
            noise_enabled           <= 0;
            pulse1_sweep_write      <= 0;
            pulse1_timer_lo_write   <= 0;
            pulse1_timer_hi_write   <= 0;
            pulse1_timer_lo_wdata   <= 0;
            pulse1_timer_hi_wdata   <= 0;
            pulse2_sweep_write      <= 0;
            pulse2_timer_lo_write   <= 0;
            pulse2_timer_hi_write   <= 0;
            pulse2_timer_lo_wdata   <= 0;
            pulse2_timer_hi_wdata   <= 0;
            triangle_timer_lo_write <= 0;
            triangle_timer_hi_write <= 0;
            triangle_timer_lo_wdata <= 0;
            triangle_timer_hi_wdata <= 0;
            noise_length_write      <= 0;
            noise_length_wdata      <= 0;
            status_write            <= 0;
            status_wdata            <= 0;
            frame_counter_write     <= 0;
            frame_counter_mode_next <= 0;
        end else if (!stall) begin
            pulse1_sweep_write      <= 0;
            pulse1_timer_lo_write   <= 0;
            pulse1_timer_hi_write   <= 0;
            pulse2_sweep_write      <= 0;
            pulse2_timer_lo_write   <= 0;
            pulse2_timer_hi_write   <= 0;
            triangle_timer_lo_write <= 0;
            triangle_timer_hi_write <= 0;
            noise_length_write      <= 0;
            status_write            <= 0;
            frame_counter_write     <= 0;

            if (!bus_stall) begin
                cpubus.rdata <= {
                    4'b0000, ((noise_length_counter != 0) ? ( 1'b1 ) : ( 1'b0 )),
                    ((triangle_length_counter != 0) ? ( 1'b1 ) : ( 1'b0 )),
                    ((pulse2_length_counter != 0) ? ( 1'b1 ) : ( 1'b0 )),
                    ((pulse1_length_counter != 0) ? ( 1'b1 ) : ( 1'b0 ))
                };
            end

            if ((!bus_stall && cpubus.wen)) begin
                case ((cpubus.addr)) inside
                    PULSE1_CTRL_ADDR: begin
                        pulse1_reg_ctrl <= cpubus.wdata;
                    end
                    PULSE1_SWEEP_ADDR: begin
                        pulse1_reg_sweep   <= cpubus.wdata;
                        pulse1_sweep_write <= 1;
                    end
                    PULSE1_TIMER_LO_ADDR: begin
                        pulse1_timer_lo_write <= 1;
                        pulse1_timer_lo_wdata <= cpubus.wdata;
                    end
                    PULSE1_TIMER_HI_ADDR: begin
                        pulse1_timer_hi_write <= 1;
                        pulse1_timer_hi_wdata <= cpubus.wdata;
                    end
                    PULSE2_CTRL_ADDR: begin
                        pulse2_reg_ctrl <= cpubus.wdata;
                    end
                    PULSE2_SWEEP_ADDR: begin
                        pulse2_reg_sweep   <= cpubus.wdata;
                        pulse2_sweep_write <= 1;
                    end
                    PULSE2_TIMER_LO_ADDR: begin
                        pulse2_timer_lo_write <= 1;
                        pulse2_timer_lo_wdata <= cpubus.wdata;
                    end
                    PULSE2_TIMER_HI_ADDR: begin
                        pulse2_timer_hi_write <= 1;
                        pulse2_timer_hi_wdata <= cpubus.wdata;
                    end
                    TRIANGLE_LINEAR_ADDR: begin
                        triangle_reg_linear <= cpubus.wdata;
                    end
                    TRIANGLE_TIMER_LO_ADDR: begin
                        triangle_timer_lo_write <= 1;
                        triangle_timer_lo_wdata <= cpubus.wdata;
                    end
                    TRIANGLE_TIMER_HI_ADDR: begin
                        triangle_timer_hi_write <= 1;
                        triangle_timer_hi_wdata <= cpubus.wdata;
                    end
                    NOISE_CTRL_ADDR: begin
                        noise_reg_ctrl <= cpubus.wdata;
                    end
                    NOISE_PERIOD_ADDR: begin
                        noise_reg_period <= cpubus.wdata;
                    end
                    NOISE_LENGTH_ADDR: begin
                        noise_length_write <= 1;
                        noise_length_wdata <= cpubus.wdata;
                    end
                    STATUS_ADDR: begin
                        pulse1_enabled   <= cpubus.wdata[0];
                        pulse2_enabled   <= cpubus.wdata[1];
                        triangle_enabled <= cpubus.wdata[2];
                        noise_enabled    <= cpubus.wdata[3];
                        status_write     <= 1;
                        status_wdata     <= cpubus.wdata;
                    end
                    FRAME_COUNTER_ADDR: begin
                        frame_counter_write     <= 1;
                        frame_counter_mode_next <= cpubus.wdata[7];
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst) begin
            pulse1_timer_period         <= 0;
            pulse1_timer_counter        <= 0;
            pulse1_sequencer            <= 0;
            pulse1_length_counter       <= 0;
            pulse1_sweep_divider        <= 0;
            pulse1_env_start            <= 0;
            pulse1_env_divider          <= 0;
            pulse1_env_decay            <= 0;
            pulse2_timer_period         <= 0;
            pulse2_timer_counter        <= 0;
            pulse2_sequencer            <= 0;
            pulse2_length_counter       <= 0;
            pulse2_sweep_divider        <= 0;
            pulse2_env_start            <= 0;
            pulse2_env_divider          <= 0;
            pulse2_env_decay            <= 0;
            triangle_timer_period       <= 0;
            triangle_timer_counter      <= 0;
            triangle_sequencer          <= 0;
            triangle_length_counter     <= 0;
            triangle_linear_counter     <= 0;
            triangle_linear_reload_flag <= 0;
            noise_timer_counter         <= 0;
            noise_length_counter        <= 0;
            noise_shift                 <= 15'h0001;
            noise_env_start             <= 0;
            noise_env_divider           <= 0;
            noise_env_decay             <= 0;
            apu_tick_div                <= 0;
            apu_half_tick               <= 0;
            frame_counter_mode          <= 0;
            frame_counter               <= 0;
        end else if (!stall) begin
            if ((pulse1_sweep_write)) begin
                pulse1_sweep_divider <= pulse1_reg_sweep.period;
            end
            if ((pulse1_timer_lo_write)) begin
                pulse1_timer_period[7:0] <= pulse1_timer_lo_wdata;
            end
            if ((pulse1_timer_hi_write)) begin
                pulse1_timer_period[10:8] <= pulse1_timer_hi_wdata[2:0];
                pulse1_sequencer          <= 0;
                pulse1_timer_counter      <= {pulse1_timer_hi_wdata[2:0], pulse1_timer_period[7:0]};
                pulse1_env_start          <= 1;
                if ((pulse1_enabled)) begin
                    pulse1_length_counter <= LENGTH_TABLE[pulse1_timer_hi_wdata[7:3]];
                end
            end
            if ((pulse2_sweep_write)) begin
                pulse2_sweep_divider <= pulse2_reg_sweep.period;
            end
            if ((pulse2_timer_lo_write)) begin
                pulse2_timer_period[7:0] <= pulse2_timer_lo_wdata;
            end
            if ((pulse2_timer_hi_write)) begin
                pulse2_timer_period[10:8] <= pulse2_timer_hi_wdata[2:0];
                pulse2_sequencer          <= 0;
                pulse2_timer_counter      <= {pulse2_timer_hi_wdata[2:0], pulse2_timer_period[7:0]};
                pulse2_env_start          <= 1;
                if ((pulse2_enabled)) begin
                    pulse2_length_counter <= LENGTH_TABLE[pulse2_timer_hi_wdata[7:3]];
                end
            end
            if ((triangle_timer_lo_write)) begin
                triangle_timer_period[7:0] <= triangle_timer_lo_wdata;
            end
            if ((triangle_timer_hi_write)) begin
                triangle_timer_period[10:8] <= triangle_timer_hi_wdata[2:0];
                triangle_timer_counter      <= {triangle_timer_hi_wdata[2:0], triangle_timer_period[7:0]};
                triangle_linear_reload_flag <= 1;
                if ((triangle_enabled)) begin
                    triangle_length_counter <= LENGTH_TABLE[triangle_timer_hi_wdata[7:3]];
                end
            end
            if ((noise_length_write && noise_enabled)) begin
                noise_length_counter <= LENGTH_TABLE[noise_length_wdata[7:3]];
                noise_env_start      <= 1;
            end
            if ((status_write)) begin
                if ((!status_wdata[0])) begin
                    pulse1_length_counter <= 0;
                end
                if ((!status_wdata[1])) begin
                    pulse2_length_counter <= 0;
                end
                if ((!status_wdata[2])) begin
                    triangle_length_counter <= 0;
                end
                if ((!status_wdata[3])) begin
                    noise_length_counter <= 0;
                end
            end

            if ((frame_counter_write)) begin
                frame_counter_mode <= frame_counter_mode_next;
                frame_counter      <= 0;
            end

            if ((frame_quarter_tick)) begin
                if ((pulse1_env_start)) begin
                    pulse1_env_start   <= 0;
                    pulse1_env_decay   <= 4'hF;
                    pulse1_env_divider <= pulse1_reg_ctrl.volume;
                end else if ((pulse1_env_divider == 0)) begin
                    pulse1_env_divider <= pulse1_reg_ctrl.volume;
                    if ((pulse1_env_decay != 0)) begin
                        pulse1_env_decay <= pulse1_env_decay - 1;
                    end else if ((pulse1_reg_ctrl.length_counter_halt)) begin
                        pulse1_env_decay <= 4'hF;
                    end
                end else begin
                    pulse1_env_divider <= pulse1_env_divider - 1;
                end
                if ((pulse2_env_start)) begin
                    pulse2_env_start   <= 0;
                    pulse2_env_decay   <= 4'hF;
                    pulse2_env_divider <= pulse2_reg_ctrl.volume;
                end else if ((pulse2_env_divider == 0)) begin
                    pulse2_env_divider <= pulse2_reg_ctrl.volume;
                    if ((pulse2_env_decay != 0)) begin
                        pulse2_env_decay <= pulse2_env_decay - 1;
                    end else if ((pulse2_reg_ctrl.length_counter_halt)) begin
                        pulse2_env_decay <= 4'hF;
                    end
                end else begin
                    pulse2_env_divider <= pulse2_env_divider - 1;
                end
                if ((noise_env_start)) begin
                    noise_env_start   <= 0;
                    noise_env_decay   <= 4'hF;
                    noise_env_divider <= noise_reg_ctrl.volume;
                end else if ((noise_env_divider == 0)) begin
                    noise_env_divider <= noise_reg_ctrl.volume;
                    if ((noise_env_decay != 0)) begin
                        noise_env_decay <= noise_env_decay - 1;
                    end else if ((noise_reg_ctrl.length_counter_halt)) begin
                        noise_env_decay <= 4'hF;
                    end
                end else begin
                    noise_env_divider <= noise_env_divider - 1;
                end
                if ((triangle_linear_reload_flag)) begin
                    triangle_linear_counter <= triangle_reg_linear.reload;
                end else if ((triangle_linear_counter != 0)) begin
                    triangle_linear_counter <= triangle_linear_counter - 1;
                end
                if ((!triangle_reg_linear.control)) begin
                    triangle_linear_reload_flag <= 0;
                end
            end

            if ((frame_half_tick)) begin
                if ((!pulse1_reg_ctrl.length_counter_halt && pulse1_length_counter != 0)) begin
                    pulse1_length_counter <= pulse1_length_counter - 1;
                end
                if ((!pulse2_reg_ctrl.length_counter_halt && pulse2_length_counter != 0)) begin
                    pulse2_length_counter <= pulse2_length_counter - 1;
                end
                if ((!triangle_reg_linear.control && triangle_length_counter != 0)) begin
                    triangle_length_counter <= triangle_length_counter - 1;
                end
                if ((!noise_reg_ctrl.length_counter_halt && noise_length_counter != 0)) begin
                    noise_length_counter <= noise_length_counter - 1;
                end
                if ((pulse1_reg_sweep.enabled && pulse1_reg_sweep.shift != 0)) begin
                    if ((pulse1_sweep_divider == 0)) begin
                        pulse1_sweep_divider <= pulse1_reg_sweep.period;
                        if ((!pulse1_sweep_mute)) begin
                            pulse1_timer_period <= pulse1_sweep_target[10:0];
                        end
                    end else begin
                        pulse1_sweep_divider <= pulse1_sweep_divider - 1;
                    end
                end
                if ((pulse2_reg_sweep.enabled && pulse2_reg_sweep.shift != 0)) begin
                    if ((pulse2_sweep_divider == 0)) begin
                        pulse2_sweep_divider <= pulse2_reg_sweep.period;
                        if ((!pulse2_sweep_mute)) begin
                            pulse2_timer_period <= pulse2_sweep_target[10:0];
                        end
                    end else begin
                        pulse2_sweep_divider <= pulse2_sweep_divider - 1;
                    end
                end
            end

            if ((apu_tick_div == 2)) begin
                apu_tick_div  <= 0;
                apu_half_tick <= !apu_half_tick;
                if ((!frame_counter_write)) begin
                    if ((frame_counter_last)) begin
                        frame_counter <= 0;
                    end else begin
                        frame_counter <= frame_counter + 1;
                    end
                end else begin
                    frame_counter <= 0;
                end

                if ((apu_half_tick)) begin
                    if ((pulse1_timer_counter == 0)) begin
                        pulse1_timer_counter <= pulse1_timer_period;
                        pulse1_sequencer     <= pulse1_sequencer + 1;
                    end else begin
                        pulse1_timer_counter <= pulse1_timer_counter - 1;
                    end
                    if ((pulse2_timer_counter == 0)) begin
                        pulse2_timer_counter <= pulse2_timer_period;
                        pulse2_sequencer     <= pulse2_sequencer + 1;
                    end else begin
                        pulse2_timer_counter <= pulse2_timer_counter - 1;
                    end
                    if ((noise_timer_counter == 0)) begin
                        noise_timer_counter <= noise_timer_period;
                        noise_shift         <= {noise_feedback, noise_shift[14:1]};
                    end else begin
                        noise_timer_counter <= noise_timer_counter - 1;
                    end
                end
                if ((triangle_timer_counter == 0)) begin
                    triangle_timer_counter <= triangle_timer_period;
                    if ((triangle_enabled && triangle_length_counter != 0 && triangle_linear_counter != 0)) begin
                        triangle_sequencer <= triangle_sequencer + 1;
                    end
                end else begin
                    triangle_timer_counter <= triangle_timer_counter - 1;
                end
            end else begin
                apu_tick_div <= apu_tick_div + 1;
            end
        end
    end

endmodule
//# sourceMappingURL=apu.sv.map
