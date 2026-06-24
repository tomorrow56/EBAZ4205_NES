interface tarunes___bus_if__8__5;
    logic [5-1:0] addr ;
    logic          wen  ;
    logic [8-1:0]  wdata;
    logic [8-1:0]  rdata;

    modport master (
        output addr ,
        output wen  ,
        output wdata,
        input  rdata
    );

    modport slave (
        input  addr ,
        input  wen  ,
        input  wdata,
        output rdata
    );

endinterface
interface tarunes___bus_if__8__16;
    logic [16-1:0] addr ;
    logic          wen  ;
    logic [8-1:0]  wdata;
    logic [8-1:0]  rdata;

    modport master (
        output addr ,
        output wen  ,
        output wdata,
        input  rdata
    );

    modport slave (
        input  addr ,
        input  wen  ,
        input  wdata,
        output rdata
    );

endinterface
interface tarunes___bus_if__8__3;
    logic [3-1:0] addr ;
    logic          wen  ;
    logic [8-1:0]  wdata;
    logic [8-1:0]  rdata;

    modport master (
        output addr ,
        output wen  ,
        output wdata,
        input  rdata
    );

    modport slave (
        input  addr ,
        input  wen  ,
        input  wdata,
        output rdata
    );

endinterface
interface tarunes___bus_if__8__1;
    logic [1-1:0] addr ;
    logic          wen  ;
    logic [8-1:0]  wdata;
    logic [8-1:0]  rdata;

    modport master (
        output addr ,
        output wen  ,
        output wdata,
        input  rdata
    );

    modport slave (
        input  addr ,
        input  wen  ,
        input  wdata,
        output rdata
    );

endinterface
interface tarunes___bus_if__8__11;
    logic [11-1:0] addr ;
    logic          wen  ;
    logic [8-1:0]  wdata;
    logic [8-1:0]  rdata;

    modport master (
        output addr ,
        output wen  ,
        output wdata,
        input  rdata
    );

    modport slave (
        input  addr ,
        input  wen  ,
        input  wdata,
        output rdata
    );

endinterface
interface tarunes___bus_if__8__15;
    logic [15-1:0] addr ;
    logic          wen  ;
    logic [8-1:0]  wdata;
    logic [8-1:0]  rdata;

    modport master (
        output addr ,
        output wen  ,
        output wdata,
        input  rdata
    );

    modport slave (
        input  addr ,
        input  wen  ,
        input  wdata,
        output rdata
    );

endinterface
interface tarunes___bus_if__8__14;
    logic [14-1:0] addr ;
    logic          wen  ;
    logic [8-1:0]  wdata;
    logic [8-1:0]  rdata;

    modport master (
        output addr ,
        output wen  ,
        output wdata,
        input  rdata
    );

    modport slave (
        input  addr ,
        input  wen  ,
        input  wdata,
        output rdata
    );

endinterface
interface tarunes___bus_if__8__13;
    logic [13-1:0] addr ;
    logic          wen  ;
    logic [8-1:0]  wdata;
    logic [8-1:0]  rdata;

    modport master (
        output addr ,
        output wen  ,
        output wdata,
        input  rdata
    );

    modport slave (
        input  addr ,
        input  wen  ,
        input  wdata,
        output rdata
    );

endinterface
//# sourceMappingURL=bus_if.sv.map
