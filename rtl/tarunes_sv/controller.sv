module tarunes_controller (
    input var logic                            clk             ,
    input var logic                            rst             ,
    input var logic                            stall           ,
    input var logic                            sel             ,
    input var logic                    [8-1:0] controller1_btns,
    input var logic                    [8-1:0] controller2_btns,
    tarunes___bus_if__8__1.slave         cpubus      
);
    logic         strobe    ;
    logic [8-1:0] shift1    ;
    logic [8-1:0] shift2    ;
    logic [4-1:0] count1    ;
    logic [4-1:0] count2    ;
    logic         sel_d     ;
    logic         read_pulse;

    // TODO: bus_ifにread enableを追加したら、sel立ち上がりではなく
    // CPUの実readサイクル1回だけでシフトするように置き換える。
    always_comb read_pulse = sel && !sel_d && !cpubus.wen;

    always_ff @ (posedge clk) begin
        if (!rst) begin
            cpubus.rdata <= 0;
            strobe       <= 0;
            shift1       <= 0;
            shift2       <= 0;
            count1       <= 0;
            count2       <= 0;
            sel_d        <= 0;
        end else if (!stall) begin
            sel_d <= sel;

            if ((strobe)) begin
                shift1 <= controller1_btns;
                shift2 <= controller2_btns;
                count1 <= 0;
                count2 <= 0;
            end

            if ((sel && cpubus.wen && cpubus.addr == 0)) begin
                strobe <= cpubus.wdata[0];
                if ((cpubus.wdata[0])) begin
                    shift1 <= controller1_btns;
                    shift2 <= controller2_btns;
                    count1 <= 0;
                    count2 <= 0;
                end
            end else if ((sel && !cpubus.wen)) begin
                case ((cpubus.addr))
                    0: begin
                        logic         read1_bit   ;
                        logic [8-1:0] read1_data  ;
                        read1_bit    = ((count1 < 8) ? ( shift1[0] ) : ( 1'b1 ));
                        read1_data   = {7'b0000000, read1_bit};
                        cpubus.rdata <= read1_data;
                        if ((read_pulse && !strobe && count1 < 8)) begin
                            shift1 <= {1'b1, shift1[7:1]};
                            count1 <= count1 + 1;
                        end
                    end
                    1: begin
                        cpubus.rdata <= {7'b0000000, ((count2 < 8) ? ( shift2[0] ) : ( 1'b1 ))};
                        if ((read_pulse && !strobe && count2 < 8)) begin
                            shift2 <= {1'b1, shift2[7:1]};
                            count2 <= count2 + 1;
                        end
                    end
                    default: begin
                        cpubus.rdata <= 0;
                    end
                endcase
            end
        end
    end
endmodule
//# sourceMappingURL=controller.sv.map
