module tarunes___memory__8__11 #(
    parameter string PATH = ""
) (
    input var logic                     clk   ,
    input var logic                     rst   ,
    input var logic                     stall ,
    tarunes___bus_if__8__11.slave membus
);
    logic [8-1:0] mem [2 ** 11];

    initial begin
        if (PATH != "") begin
            $readmemh(PATH, mem);
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst) begin
            membus.rdata <= 0;
        end else if (!stall) begin
            membus.rdata <= mem[membus.addr];
            if (membus.wen) begin
                mem[membus.addr] <= membus.wdata;
            end
        end
    end
endmodule
module tarunes___memory__8__15 #(
    parameter string PATH = ""
) (
    input var logic                     clk   ,
    input var logic                     rst   ,
    input var logic                     stall ,
    tarunes___bus_if__8__15.slave membus
);
    logic [8-1:0] mem [2 ** 15];

    initial begin
        if (PATH != "") begin
            $readmemh(PATH, mem);
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst) begin
            membus.rdata <= 0;
        end else if (!stall) begin
            membus.rdata <= mem[membus.addr];
            if (membus.wen) begin
                mem[membus.addr] <= membus.wdata;
            end
        end
    end
endmodule
module tarunes___memory__8__13 #(
    parameter string PATH = ""
) (
    input var logic                     clk   ,
    input var logic                     rst   ,
    input var logic                     stall ,
    tarunes___bus_if__8__13.slave membus
);
    logic [8-1:0] mem [2 ** 13];

    initial begin
        if (PATH != "") begin
            $readmemh(PATH, mem);
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst) begin
            membus.rdata <= 0;
        end else if (!stall) begin
            membus.rdata <= mem[membus.addr];
            if (membus.wen) begin
                mem[membus.addr] <= membus.wdata;
            end
        end
    end
endmodule
//# sourceMappingURL=memory.sv.map
