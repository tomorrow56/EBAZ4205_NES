module tarunes_cpu (
    input  var logic                               clk           ,
    input  var logic                               rst           ,
    input  var logic                               stall         ,
    input  var logic                               nmi           ,
    input  var logic                               halt          ,
    output var logic                      [16-1:0] debug_pc      ,
    output var logic                      [16-1:0] logic_analizer,
    tarunes___bus_if__8__16.master          cpubus    
);
    // CPU Registers
    logic [8-1:0]  reg_a ; // Accumulator
    logic [8-1:0]  reg_x ; // X register
    logic [8-1:0]  reg_y ; // Y register
    logic [8-1:0]  reg_sp; // Stack pointer
    logic [16-1:0] reg_pc; // Program counter
    logic [8-1:0]  reg_p ; // Status Register

    logic [8-1:0]  op1             ;
    logic [8-1:0]  op2             ;
    logic [8-1:0]  ptr_addr        ;
    logic [16-1:0] eff_addr        ;
    logic [16-1:0] return_addr     ;
    logic [16-1:0] interrupt_vector;
    logic [8-1:0]  interrupt_status;
    logic [16-1:0] inst_len        ;
    logic          nmi_d           ;
    logic          nmi_pending     ;

    typedef enum logic [6-1:0] {
        inst_t_INVALID,
        inst_t_BRK,
        inst_t_RTI,
        inst_t_PHA,
        inst_t_PLA,
        inst_t_PHP,
        inst_t_PLP,
        inst_t_SEI,
        inst_t_SEC,
        inst_t_CLI,
        inst_t_CLD,
        inst_t_CLC,
        inst_t_SED,
        inst_t_CLV,
        inst_t_NOP,
        inst_t_TXS,
        inst_t_TSX,
        inst_t_TAX,
        inst_t_TXA,
        inst_t_TAY,
        inst_t_TYA,
        inst_t_INX,
        inst_t_INY,
        inst_t_INC,
        inst_t_DEC,
        inst_t_ASL,
        inst_t_LSR,
        inst_t_ROL,
        inst_t_ROR,
        inst_t_DEX,
        inst_t_DEY,
        inst_t_LDA,
        inst_t_LDX,
        inst_t_LDY,
        inst_t_CPX,
        inst_t_CPY,
        inst_t_CMP,
        inst_t_ADC,
        inst_t_SBC,
        inst_t_ORA,
        inst_t_AND,
        inst_t_EOR,
        inst_t_STA,
        inst_t_STX,
        inst_t_STY,
        inst_t_BIT,
        inst_t_BCC,
        inst_t_BCS,
        inst_t_BNE,
        inst_t_BEQ,
        inst_t_BPL,
        inst_t_BMI,
        inst_t_BVC,
        inst_t_BVS,
        inst_t_JMP,
        inst_t_JSR,
        inst_t_RTS
    } inst_t;
    inst_t decoded_inst;

    typedef enum logic [4-1:0] {
        addr_mode_t_IMPLIED,
        addr_mode_t_IMM,
        addr_mode_t_ZP,
        addr_mode_t_ZPX,
        addr_mode_t_ZPY,
        addr_mode_t_ABS,
        addr_mode_t_ABSX,
        addr_mode_t_ABSY,
        addr_mode_t_IND,
        addr_mode_t_INDX,
        addr_mode_t_INDY,
        addr_mode_t_REL
    } addr_mode_t;
    addr_mode_t addr_mode;

    typedef struct packed {
        logic       [8-1:0]  opcode   ;
        inst_t               inst_kind;
        addr_mode_t          mode     ;
        logic       [16-1:0] len      ;
    } decode_entry_t;
    localparam decode_entry_t DECODE_TABLE [151] = '{
        decode_entry_t'{opcode: 8'h00, inst_kind: inst_t_BRK, mode: addr_mode_t_IMPLIED, len: 2},
        decode_entry_t'{opcode: 8'h40, inst_kind: inst_t_RTI, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h48, inst_kind: inst_t_PHA, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h68, inst_kind: inst_t_PLA, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h08, inst_kind: inst_t_PHP, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h28, inst_kind: inst_t_PLP, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h78, inst_kind: inst_t_SEI, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h38, inst_kind: inst_t_SEC, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h58, inst_kind: inst_t_CLI, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'hD8, inst_kind: inst_t_CLD, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h18, inst_kind: inst_t_CLC, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'hF8, inst_kind: inst_t_SED, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'hB8, inst_kind: inst_t_CLV, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'hEA, inst_kind: inst_t_NOP, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h9A, inst_kind: inst_t_TXS, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'hBA, inst_kind: inst_t_TSX, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'hAA, inst_kind: inst_t_TAX, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h8A, inst_kind: inst_t_TXA, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'hA8, inst_kind: inst_t_TAY, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h98, inst_kind: inst_t_TYA, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'hE8, inst_kind: inst_t_INX, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'hC8, inst_kind: inst_t_INY, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'hE6, inst_kind: inst_t_INC, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'hF6, inst_kind: inst_t_INC, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'hEE, inst_kind: inst_t_INC, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'hFE, inst_kind: inst_t_INC, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'hC6, inst_kind: inst_t_DEC, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'hD6, inst_kind: inst_t_DEC, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'hCE, inst_kind: inst_t_DEC, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'hDE, inst_kind: inst_t_DEC, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'h0A, inst_kind: inst_t_ASL, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h06, inst_kind: inst_t_ASL, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h16, inst_kind: inst_t_ASL, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'h0E, inst_kind: inst_t_ASL, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h1E, inst_kind: inst_t_ASL, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'h4A, inst_kind: inst_t_LSR, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h46, inst_kind: inst_t_LSR, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h56, inst_kind: inst_t_LSR, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'h4E, inst_kind: inst_t_LSR, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h5E, inst_kind: inst_t_LSR, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'h2A, inst_kind: inst_t_ROL, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h26, inst_kind: inst_t_ROL, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h36, inst_kind: inst_t_ROL, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'h2E, inst_kind: inst_t_ROL, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h3E, inst_kind: inst_t_ROL, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'h6A, inst_kind: inst_t_ROR, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h66, inst_kind: inst_t_ROR, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h76, inst_kind: inst_t_ROR, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'h6E, inst_kind: inst_t_ROR, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h7E, inst_kind: inst_t_ROR, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'hCA, inst_kind: inst_t_DEX, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'h88, inst_kind: inst_t_DEY, mode: addr_mode_t_IMPLIED, len: 1},
        decode_entry_t'{opcode: 8'hA9, inst_kind: inst_t_LDA, mode: addr_mode_t_IMM, len: 2},
        decode_entry_t'{opcode: 8'hA5, inst_kind: inst_t_LDA, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'hB5, inst_kind: inst_t_LDA, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'hAD, inst_kind: inst_t_LDA, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'hBD, inst_kind: inst_t_LDA, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'hB9, inst_kind: inst_t_LDA, mode: addr_mode_t_ABSY, len: 3},
        decode_entry_t'{opcode: 8'hA1, inst_kind: inst_t_LDA, mode: addr_mode_t_INDX, len: 2},
        decode_entry_t'{opcode: 8'hB1, inst_kind: inst_t_LDA, mode: addr_mode_t_INDY, len: 2},
        decode_entry_t'{opcode: 8'hA2, inst_kind: inst_t_LDX, mode: addr_mode_t_IMM, len: 2},
        decode_entry_t'{opcode: 8'hA6, inst_kind: inst_t_LDX, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'hB6, inst_kind: inst_t_LDX, mode: addr_mode_t_ZPY, len: 2},
        decode_entry_t'{opcode: 8'hAE, inst_kind: inst_t_LDX, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'hBE, inst_kind: inst_t_LDX, mode: addr_mode_t_ABSY, len: 3},
        decode_entry_t'{opcode: 8'hA0, inst_kind: inst_t_LDY, mode: addr_mode_t_IMM, len: 2},
        decode_entry_t'{opcode: 8'hA4, inst_kind: inst_t_LDY, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'hB4, inst_kind: inst_t_LDY, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'hAC, inst_kind: inst_t_LDY, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'hBC, inst_kind: inst_t_LDY, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'hE0, inst_kind: inst_t_CPX, mode: addr_mode_t_IMM, len: 2},
        decode_entry_t'{opcode: 8'hE4, inst_kind: inst_t_CPX, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'hEC, inst_kind: inst_t_CPX, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'hC0, inst_kind: inst_t_CPY, mode: addr_mode_t_IMM, len: 2},
        decode_entry_t'{opcode: 8'hC4, inst_kind: inst_t_CPY, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'hCC, inst_kind: inst_t_CPY, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'hC9, inst_kind: inst_t_CMP, mode: addr_mode_t_IMM, len: 2},
        decode_entry_t'{opcode: 8'hC5, inst_kind: inst_t_CMP, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'hD5, inst_kind: inst_t_CMP, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'hCD, inst_kind: inst_t_CMP, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'hDD, inst_kind: inst_t_CMP, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'hD9, inst_kind: inst_t_CMP, mode: addr_mode_t_ABSY, len: 3},
        decode_entry_t'{opcode: 8'hC1, inst_kind: inst_t_CMP, mode: addr_mode_t_INDX, len: 2},
        decode_entry_t'{opcode: 8'hD1, inst_kind: inst_t_CMP, mode: addr_mode_t_INDY, len: 2},
        decode_entry_t'{opcode: 8'h69, inst_kind: inst_t_ADC, mode: addr_mode_t_IMM, len: 2},
        decode_entry_t'{opcode: 8'h65, inst_kind: inst_t_ADC, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h75, inst_kind: inst_t_ADC, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'h6D, inst_kind: inst_t_ADC, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h7D, inst_kind: inst_t_ADC, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'h79, inst_kind: inst_t_ADC, mode: addr_mode_t_ABSY, len: 3},
        decode_entry_t'{opcode: 8'h61, inst_kind: inst_t_ADC, mode: addr_mode_t_INDX, len: 2},
        decode_entry_t'{opcode: 8'h71, inst_kind: inst_t_ADC, mode: addr_mode_t_INDY, len: 2},
        decode_entry_t'{opcode: 8'hE9, inst_kind: inst_t_SBC, mode: addr_mode_t_IMM, len: 2},
        decode_entry_t'{opcode: 8'hE5, inst_kind: inst_t_SBC, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'hF5, inst_kind: inst_t_SBC, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'hED, inst_kind: inst_t_SBC, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'hFD, inst_kind: inst_t_SBC, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'hF9, inst_kind: inst_t_SBC, mode: addr_mode_t_ABSY, len: 3},
        decode_entry_t'{opcode: 8'hE1, inst_kind: inst_t_SBC, mode: addr_mode_t_INDX, len: 2},
        decode_entry_t'{opcode: 8'hF1, inst_kind: inst_t_SBC, mode: addr_mode_t_INDY, len: 2},
        decode_entry_t'{opcode: 8'h09, inst_kind: inst_t_ORA, mode: addr_mode_t_IMM, len: 2},
        decode_entry_t'{opcode: 8'h05, inst_kind: inst_t_ORA, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h15, inst_kind: inst_t_ORA, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'h0D, inst_kind: inst_t_ORA, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h1D, inst_kind: inst_t_ORA, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'h19, inst_kind: inst_t_ORA, mode: addr_mode_t_ABSY, len: 3},
        decode_entry_t'{opcode: 8'h01, inst_kind: inst_t_ORA, mode: addr_mode_t_INDX, len: 2},
        decode_entry_t'{opcode: 8'h11, inst_kind: inst_t_ORA, mode: addr_mode_t_INDY, len: 2},
        decode_entry_t'{opcode: 8'h29, inst_kind: inst_t_AND, mode: addr_mode_t_IMM, len: 2},
        decode_entry_t'{opcode: 8'h25, inst_kind: inst_t_AND, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h35, inst_kind: inst_t_AND, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'h2D, inst_kind: inst_t_AND, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h3D, inst_kind: inst_t_AND, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'h39, inst_kind: inst_t_AND, mode: addr_mode_t_ABSY, len: 3},
        decode_entry_t'{opcode: 8'h21, inst_kind: inst_t_AND, mode: addr_mode_t_INDX, len: 2},
        decode_entry_t'{opcode: 8'h31, inst_kind: inst_t_AND, mode: addr_mode_t_INDY, len: 2},
        decode_entry_t'{opcode: 8'h49, inst_kind: inst_t_EOR, mode: addr_mode_t_IMM, len: 2},
        decode_entry_t'{opcode: 8'h45, inst_kind: inst_t_EOR, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h55, inst_kind: inst_t_EOR, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'h4D, inst_kind: inst_t_EOR, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h5D, inst_kind: inst_t_EOR, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'h59, inst_kind: inst_t_EOR, mode: addr_mode_t_ABSY, len: 3},
        decode_entry_t'{opcode: 8'h41, inst_kind: inst_t_EOR, mode: addr_mode_t_INDX, len: 2},
        decode_entry_t'{opcode: 8'h51, inst_kind: inst_t_EOR, mode: addr_mode_t_INDY, len: 2},
        decode_entry_t'{opcode: 8'h24, inst_kind: inst_t_BIT, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h2C, inst_kind: inst_t_BIT, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h85, inst_kind: inst_t_STA, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h95, inst_kind: inst_t_STA, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'h8D, inst_kind: inst_t_STA, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h9D, inst_kind: inst_t_STA, mode: addr_mode_t_ABSX, len: 3},
        decode_entry_t'{opcode: 8'h99, inst_kind: inst_t_STA, mode: addr_mode_t_ABSY, len: 3},
        decode_entry_t'{opcode: 8'h81, inst_kind: inst_t_STA, mode: addr_mode_t_INDX, len: 2},
        decode_entry_t'{opcode: 8'h91, inst_kind: inst_t_STA, mode: addr_mode_t_INDY, len: 2},
        decode_entry_t'{opcode: 8'h86, inst_kind: inst_t_STX, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h96, inst_kind: inst_t_STX, mode: addr_mode_t_ZPY, len: 2},
        decode_entry_t'{opcode: 8'h8E, inst_kind: inst_t_STX, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h84, inst_kind: inst_t_STY, mode: addr_mode_t_ZP, len: 2},
        decode_entry_t'{opcode: 8'h94, inst_kind: inst_t_STY, mode: addr_mode_t_ZPX, len: 2},
        decode_entry_t'{opcode: 8'h8C, inst_kind: inst_t_STY, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h90, inst_kind: inst_t_BCC, mode: addr_mode_t_REL, len: 2},
        decode_entry_t'{opcode: 8'hB0, inst_kind: inst_t_BCS, mode: addr_mode_t_REL, len: 2},
        decode_entry_t'{opcode: 8'hD0, inst_kind: inst_t_BNE, mode: addr_mode_t_REL, len: 2},
        decode_entry_t'{opcode: 8'hF0, inst_kind: inst_t_BEQ, mode: addr_mode_t_REL, len: 2},
        decode_entry_t'{opcode: 8'h10, inst_kind: inst_t_BPL, mode: addr_mode_t_REL, len: 2},
        decode_entry_t'{opcode: 8'h30, inst_kind: inst_t_BMI, mode: addr_mode_t_REL, len: 2},
        decode_entry_t'{opcode: 8'h50, inst_kind: inst_t_BVC, mode: addr_mode_t_REL, len: 2},
        decode_entry_t'{opcode: 8'h70, inst_kind: inst_t_BVS, mode: addr_mode_t_REL, len: 2},
        decode_entry_t'{opcode: 8'h4C, inst_kind: inst_t_JMP, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h6C, inst_kind: inst_t_JMP, mode: addr_mode_t_IND, len: 3},
        decode_entry_t'{opcode: 8'h20, inst_kind: inst_t_JSR, mode: addr_mode_t_ABS, len: 3},
        decode_entry_t'{opcode: 8'h60, inst_kind: inst_t_RTS, mode: addr_mode_t_IMPLIED, len: 1}
    };

    typedef enum logic [5-1:0] {
        cpu_state_t_RESET0,
        cpu_state_t_RESET1,
        cpu_state_t_RESET2,
        cpu_state_t_FETCH,
        cpu_state_t_DECODE,
        cpu_state_t_OP1,
        cpu_state_t_OP2,
        cpu_state_t_OP3,
        cpu_state_t_JMP_IND_LO,
        cpu_state_t_JMP_IND_HI,
        cpu_state_t_EXEC,
        cpu_state_t_RMW_WRITE,
        cpu_state_t_INT_PUSH_LO,
        cpu_state_t_INT_PUSH_P,
        cpu_state_t_INT_VECTOR_LO,
        cpu_state_t_INT_VECTOR_LO_WAIT,
        cpu_state_t_INT_VECTOR_HI,
        cpu_state_t_INT_VECTOR_HI_READ,
        cpu_state_t_JSR_PUSH_LO,
        cpu_state_t_RTI_PULL_P,
        cpu_state_t_RTI_WAIT_LO,
        cpu_state_t_RTI_PULL_HI,
        cpu_state_t_RTS_PULL_LO,
        cpu_state_t_RTS_WAIT_HI
    } cpu_state_t;
    cpu_state_t state;

    function automatic logic [64-1:0] debug_cpu_state_str(
        input var cpu_state_t debug_state
    ) ;
        case ((debug_state))
            cpu_state_t_RESET0            : return "RESET0";
            cpu_state_t_RESET1            : return "RESET1";
            cpu_state_t_RESET2            : return "RESET2";
            cpu_state_t_FETCH             : return "FETCH";
            cpu_state_t_DECODE            : return "DECODE";
            cpu_state_t_OP1               : return "OP1";
            cpu_state_t_OP2               : return "OP2";
            cpu_state_t_OP3               : return "OP3";
            cpu_state_t_JMP_IND_LO        : return "JMP_IL";
            cpu_state_t_JMP_IND_HI        : return "JMP_IH";
            cpu_state_t_EXEC              : return "EXEC";
            cpu_state_t_RMW_WRITE         : return "RMW_WR";
            cpu_state_t_INT_PUSH_LO       : return "INT_LO";
            cpu_state_t_INT_PUSH_P        : return "INT_P";
            cpu_state_t_INT_VECTOR_LO     : return "INT_VL";
            cpu_state_t_INT_VECTOR_LO_WAIT: return "INT_WL";
            cpu_state_t_INT_VECTOR_HI     : return "INT_VH";
            cpu_state_t_INT_VECTOR_HI_READ: return "INT_RH";
            cpu_state_t_JSR_PUSH_LO       : return "JSR_LO";
            cpu_state_t_RTI_PULL_P        : return "RTI_P";
            cpu_state_t_RTI_WAIT_LO       : return "RTI_WAIT";
            cpu_state_t_RTI_PULL_HI       : return "RTI_HI";
            cpu_state_t_RTS_PULL_LO       : return "RTS_LO";
            cpu_state_t_RTS_WAIT_HI       : return "RTS_WAIT";
            default                       : return "UNKNOWN";
        endcase
    endfunction

    function automatic decode_entry_t invalid_decode_entry(
        input var logic [8-1:0] raw_opcode
    ) ;
        decode_entry_t ret          ;
        ret.opcode    = raw_opcode;
        ret.inst_kind = inst_t_INVALID;
        ret.mode      = addr_mode_t_IMPLIED;
        ret.len       = 1;
        return ret;
    endfunction

    function automatic decode_entry_t decode_opcode(
        input var logic [8-1:0] raw_opcode
    ) ;
        for (int i = 0; i < $size(DECODE_TABLE); i++) begin
            if ((DECODE_TABLE[i].opcode == raw_opcode)) begin
                return DECODE_TABLE[i];
            end
        end
        return invalid_decode_entry(raw_opcode);
    endfunction

    function automatic logic is_store_inst(
        input var inst_t inst_kind
    ) ;
        return inst_kind == inst_t_STA || inst_kind == inst_t_STX || inst_kind == inst_t_STY;
    endfunction

    function automatic logic [8-1:0] high_byte(
        input var logic [16-1:0] value
    ) ;
        return value[15:8];
    endfunction

    logic [64-1:0] _state_debug  ; always_comb _state_debug   = debug_cpu_state_str(state);
    always_comb debug_pc       = reg_pc;
    always_comb logic_analizer = {!stall && !halt && state == cpu_state_t_DECODE, reg_pc[6:0], cpubus.rdata};

    always_comb begin
        cpubus.addr  = 0;
        cpubus.wen   = 0;
        cpubus.wdata = 0;

        case ((state))
            cpu_state_t_RESET0: begin
                cpubus.addr = 16'hFFFC;
            end
            cpu_state_t_RESET1: begin
                cpubus.addr = 16'hFFFD;
            end
            cpu_state_t_FETCH: begin
                cpubus.addr = reg_pc;
                if ((nmi_pending)) begin
                    cpubus.addr  = {8'h01, reg_sp};
                    cpubus.wdata = reg_pc[15:8];
                    cpubus.wen   = 1'b1;
                end
            end
            cpu_state_t_DECODE: begin
                decode_entry_t decode_entry;
                decode_entry = decode_opcode(cpubus.rdata);
                case ((decode_entry.mode))
                    addr_mode_t_IMPLIED: begin
                        case ((decode_entry.inst_kind))
                            inst_t_BRK: begin
                                logic [16-1:0] brk_return_addr;
                                brk_return_addr = reg_pc + decode_entry.len;
                                cpubus.addr     = {8'h01, reg_sp};
                                cpubus.wdata    = brk_return_addr[15:8];
                                cpubus.wen      = 1'b1;
                            end
                            inst_t_PLP, inst_t_PLA, inst_t_RTI, inst_t_RTS: begin
                                cpubus.addr = {8'h01, reg_sp + 8'd1};
                            end
                            inst_t_PHA: begin
                                cpubus.addr  = {8'h01, reg_sp};
                                cpubus.wdata = reg_a;
                                cpubus.wen   = 1'b1;
                            end
                            inst_t_PHP: begin
                                cpubus.addr  = {8'h01, reg_sp};
                                cpubus.wdata = reg_p | 8'h30;
                                cpubus.wen   = 1'b1;
                            end
                        endcase
                    end
                    addr_mode_t_IMM, addr_mode_t_ZP, addr_mode_t_ZPX, addr_mode_t_ZPY, addr_mode_t_INDX,
                    addr_mode_t_INDY, addr_mode_t_REL, addr_mode_t_ABS, addr_mode_t_ABSX, addr_mode_t_ABSY,
                    addr_mode_t_IND: begin
                        cpubus.addr = reg_pc + 1;
                    end
                endcase
            end
            cpu_state_t_OP1: begin
                case ((addr_mode))
                    addr_mode_t_ZP: begin
                        cpubus.addr = {8'h00, cpubus.rdata};
                    end
                    addr_mode_t_ZPX: begin
                        cpubus.addr = {8'h00, cpubus.rdata + reg_x};
                    end
                    addr_mode_t_ZPY: begin
                        cpubus.addr = {8'h00, cpubus.rdata + reg_y};
                    end
                    addr_mode_t_INDX: begin
                        cpubus.addr = {8'h00, cpubus.rdata + reg_x};
                    end
                    addr_mode_t_INDY: begin
                        cpubus.addr = {8'h00, cpubus.rdata};
                    end
                    addr_mode_t_ABS, addr_mode_t_ABSX, addr_mode_t_ABSY, addr_mode_t_IND: begin
                        cpubus.addr = reg_pc + 2;
                    end
                endcase
            end
            cpu_state_t_OP2: begin
                case ((addr_mode))
                    addr_mode_t_INDX: begin
                        cpubus.addr = {8'h00, ptr_addr + 8'd1};
                    end
                    addr_mode_t_INDY: begin
                        cpubus.addr = {8'h00, ptr_addr + 8'd1};
                    end
                    addr_mode_t_ABS: begin
                        if ((!is_store_inst(decoded_inst))) begin
                            cpubus.addr = {cpubus.rdata, op1};
                        end
                    end
                    addr_mode_t_ABSX: begin
                        if ((!is_store_inst(decoded_inst))) begin
                            cpubus.addr = {cpubus.rdata, op1} + reg_x;
                        end
                    end
                    addr_mode_t_ABSY: begin
                        if ((!is_store_inst(decoded_inst))) begin
                            cpubus.addr = {cpubus.rdata, op1} + reg_y;
                        end
                    end
                    addr_mode_t_IND: begin
                        cpubus.addr = {cpubus.rdata, op1};
                    end
                endcase
            end
            cpu_state_t_OP3: begin
                case ((addr_mode))
                    addr_mode_t_INDX: begin
                        if ((!is_store_inst(decoded_inst))) begin
                            cpubus.addr = {cpubus.rdata, op1};
                        end
                    end
                    addr_mode_t_INDY: begin
                        if ((!is_store_inst(decoded_inst))) begin
                            cpubus.addr = {cpubus.rdata, op1} + reg_y;
                        end
                    end
                endcase
            end
            cpu_state_t_JMP_IND_LO: begin
                cpubus.addr = {return_addr[15:8], return_addr[7:0] + 8'd1};
            end
            cpu_state_t_EXEC: begin
                case ((decoded_inst))
                    inst_t_JSR: begin
                        cpubus.addr  = {8'h01, reg_sp};
                        cpubus.wdata = high_byte(reg_pc + 16'd2);
                        cpubus.wen   = 1'b1;
                    end
                    inst_t_INC, inst_t_DEC, inst_t_ASL, inst_t_LSR, inst_t_ROL, inst_t_ROR: begin
                        cpubus.addr  = eff_addr;
                        cpubus.wdata = cpubus.rdata;
                        cpubus.wen   = 1'b1;
                    end
                    inst_t_STA: begin
                        case ((addr_mode))
                            addr_mode_t_ZP: begin
                                cpubus.addr = {8'h00, op1};
                            end
                            addr_mode_t_ZPX: begin
                                cpubus.addr = {8'h00, op1 + reg_x};
                            end
                            addr_mode_t_INDX, addr_mode_t_INDY, addr_mode_t_ABS, addr_mode_t_ABSX,
                            addr_mode_t_ABSY: begin
                                cpubus.addr = eff_addr;
                            end
                            default: begin
                                cpubus.addr = {8'h00, op1};
                            end
                        endcase
                        cpubus.wdata = reg_a;
                        cpubus.wen   = 1'b1;
                    end
                    inst_t_STX: begin
                        case ((addr_mode))
                            addr_mode_t_ZP: begin
                                cpubus.addr = {8'h00, op1};
                            end
                            addr_mode_t_ZPY: begin
                                cpubus.addr = {8'h00, op1 + reg_y};
                            end
                            addr_mode_t_ABS: begin
                                cpubus.addr = eff_addr;
                            end
                            default: begin
                                cpubus.addr = {8'h00, op1};
                            end
                        endcase
                        cpubus.wdata = reg_x;
                        cpubus.wen   = 1'b1;
                    end
                    inst_t_STY: begin
                        case ((addr_mode))
                            addr_mode_t_ZP: begin
                                cpubus.addr = {8'h00, op1};
                            end
                            addr_mode_t_ZPX: begin
                                cpubus.addr = {8'h00, op1 + reg_x};
                            end
                            addr_mode_t_ABS: begin
                                cpubus.addr = eff_addr;
                            end
                            default: begin
                                cpubus.addr = {8'h00, op1};
                            end
                        endcase
                        cpubus.wdata = reg_y;
                        cpubus.wen   = 1'b1;
                    end
                endcase
            end
            cpu_state_t_RMW_WRITE: begin
                cpubus.addr  = eff_addr;
                cpubus.wdata = op2;
                cpubus.wen   = 1'b1;
            end
            cpu_state_t_INT_PUSH_LO: begin
                cpubus.addr  = {8'h01, reg_sp};
                cpubus.wdata = return_addr[7:0];
                cpubus.wen   = 1'b1;
            end
            cpu_state_t_INT_PUSH_P: begin
                cpubus.addr  = {8'h01, reg_sp};
                cpubus.wdata = interrupt_status;
                cpubus.wen   = 1'b1;
            end
            cpu_state_t_INT_VECTOR_LO: begin
                cpubus.addr = interrupt_vector;
            end
            cpu_state_t_INT_VECTOR_HI: begin
                cpubus.addr = interrupt_vector + 16'd1;
            end
            cpu_state_t_JSR_PUSH_LO: begin
                cpubus.addr  = {8'h01, reg_sp};
                cpubus.wdata = return_addr[7:0];
                cpubus.wen   = 1'b1;
            end
            cpu_state_t_RTI_PULL_P: begin
                cpubus.addr = {8'h01, reg_sp + 8'd2};
            end
            cpu_state_t_RTI_WAIT_LO: begin
                cpubus.addr = {8'h01, reg_sp + 8'd2};
            end
            cpu_state_t_RTS_PULL_LO: begin
                cpubus.addr = {8'h01, reg_sp + 8'd2};
            end
            cpu_state_t_RTS_WAIT_HI: begin
                cpubus.addr = {8'h01, reg_sp + 8'd1};
            end
        endcase
    end

    always_ff @ (posedge clk) begin
        if (!rst) begin
            state            <= cpu_state_t_RESET0;
            reg_a            <= 0;
            reg_x            <= 0;
            reg_y            <= 0;
            reg_sp           <= 8'hFD;
            reg_p            <= 8'h24; // bit[5]=1,bit[2]=1
            reg_pc           <= 0;
            op1              <= 0;
            op2              <= 0;
            ptr_addr         <= 0;
            eff_addr         <= 0;
            return_addr      <= 0;
            interrupt_vector <= 0;
            interrupt_status <= 0;
            inst_len         <= 0;
            nmi_d            <= 0;
            nmi_pending      <= 0;
            decoded_inst     <= inst_t_INVALID;
            addr_mode        <= addr_mode_t_IMPLIED;
        end else begin
            // NMIは1clkパルスなので立ち上がりを検出して命令境界まで保持する
            nmi_pending <= nmi_pending || (nmi && !nmi_d);
            nmi_d       <= nmi;

            if ((!stall && !halt)) begin
                case (state)
                    // 0xFFFCをセット
                    cpu_state_t_RESET0: begin
                        state <= cpu_state_t_RESET1;
                    end
                    // RESET0でセットした0xFFFCのデータが反映されるので読む
                    cpu_state_t_RESET1: begin
                        reg_pc[7:0] <= cpubus.rdata;
                        state       <= cpu_state_t_RESET2;
                    end
                    // RESET1でセットした0xFFFDのデータが反映されるので読む
                    cpu_state_t_RESET2: begin
                        reg_pc[15:8] <= cpubus.rdata;
                        state        <= cpu_state_t_FETCH;
                    end
                    // PCを読み込む。opcodeは次のDECODEで受け取る。
                    cpu_state_t_FETCH: begin
                        if ((nmi_pending)) begin
                            nmi_pending      <= 0;
                            return_addr      <= reg_pc;
                            interrupt_vector <= 16'hFFFA;
                            interrupt_status <= reg_p & 8'hEF | 8'h20;
                            reg_sp           <= reg_sp - 1;
                            state            <= cpu_state_t_INT_PUSH_LO;
                        end else begin
                            state <= cpu_state_t_DECODE;
                        end
                    end
                    cpu_state_t_DECODE: begin
                        decode_entry_t decode_entry;
                        decode_entry = decode_opcode(cpubus.rdata);
                        decoded_inst <= decode_entry.inst_kind;
                        addr_mode    <= decode_entry.mode;
                        inst_len     <= decode_entry.len;

                        if ((decode_entry.inst_kind == inst_t_INVALID)) begin
                        end else begin
                            case ((decode_entry.mode))
                                addr_mode_t_IMPLIED: begin
                                    case ((decode_entry.inst_kind))
                                        inst_t_BRK: begin
                                            logic [16-1:0] brk_return_addr ;
                                            brk_return_addr  = reg_pc + decode_entry.len;
                                            return_addr      <= brk_return_addr;
                                            interrupt_vector <= 16'hFFFE;
                                            interrupt_status <= reg_p | 8'h10;
                                            reg_sp           <= reg_sp - 1;
                                            state            <= cpu_state_t_INT_PUSH_LO;
                                        end

                                        inst_t_PLP: begin
                                            state <= cpu_state_t_EXEC;
                                        end

                                        inst_t_PLA: begin
                                            state <= cpu_state_t_EXEC;
                                        end

                                        inst_t_RTI: begin
                                            state <= cpu_state_t_RTI_PULL_P;
                                        end

                                        inst_t_PHA: begin
                                            reg_sp <= reg_sp - 1;
                                            reg_pc <= reg_pc + decode_entry.len;
                                            state  <= cpu_state_t_FETCH;
                                        end

                                        inst_t_PHP: begin
                                            reg_sp <= reg_sp - 1;
                                            reg_pc <= reg_pc + decode_entry.len;
                                            state  <= cpu_state_t_FETCH;
                                        end

                                        // IRQフラグ無効
                                        // NMIはIフラグに関係なく受け付ける
                                        inst_t_SEI: begin
                                            reg_p[2] <= 1'b1;
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_SEC: begin
                                            reg_p[0] <= 1'b1;
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_CLI: begin
                                            reg_p[2] <= 1'b0;
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_CLD: begin
                                            reg_p[3] <= 1'b0;
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_CLC: begin
                                            reg_p[0] <= 1'b0;
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_SED: begin
                                            reg_p[3] <= 1'b1;
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_CLV: begin
                                            reg_p[6] <= 1'b0;
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_NOP: begin
                                            state  <= cpu_state_t_FETCH;
                                            reg_pc <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_TXS: begin
                                            reg_sp <= reg_x;
                                            // TXSはフラグ更新しない
                                            state  <= cpu_state_t_FETCH;
                                            reg_pc <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_TSX: begin
                                            reg_x    <= reg_sp;
                                            reg_p[1] <= (reg_sp == 0);
                                            reg_p[7] <= reg_sp[7];
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_TAX: begin
                                            reg_x    <= reg_a;
                                            reg_p[1] <= (reg_a == 0);
                                            reg_p[7] <= reg_a[7];
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_TXA: begin
                                            reg_a    <= reg_x;
                                            reg_p[1] <= (reg_x == 0);
                                            reg_p[7] <= reg_x[7];
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_TAY: begin
                                            reg_y    <= reg_a;
                                            reg_p[1] <= (reg_a == 0);
                                            reg_p[7] <= reg_a[7];
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_TYA: begin
                                            reg_a    <= reg_y;
                                            reg_p[1] <= (reg_y == 0);
                                            reg_p[7] <= reg_y[7];
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_ASL: begin
                                            logic [8-1:0] result  ;
                                            result   = reg_a << 1;
                                            reg_p[0] <= reg_a[7];
                                            reg_p[1] <= (result == 0);
                                            reg_p[7] <= result[7];
                                            reg_a    <= result;
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_LSR: begin
                                            logic [8-1:0] result  ;
                                            result   = reg_a >> 1;
                                            reg_p[0] <= reg_a[0];
                                            reg_p[1] <= (result == 0);
                                            reg_p[7] <= 1'b0;
                                            reg_a    <= result;
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_ROL: begin
                                            logic [8-1:0] result  ;
                                            result   = {reg_a[6:0], reg_p[0]};
                                            reg_p[0] <= reg_a[7];
                                            reg_p[1] <= (result == 0);
                                            reg_p[7] <= result[7];
                                            reg_a    <= result;
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_ROR: begin
                                            logic [8-1:0] result  ;
                                            result   = {reg_p[0], reg_a[7:1]};
                                            reg_p[0] <= reg_a[0];
                                            reg_p[1] <= (result == 0);
                                            reg_p[7] <= result[7];
                                            reg_a    <= result;
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_INX: begin
                                            logic [8-1:0] result  ;
                                            result   = reg_x + 1;
                                            reg_x    <= result;
                                            reg_p[1] <= (result == 0);
                                            reg_p[7] <= result[7];
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_INY: begin
                                            logic [8-1:0] result  ;
                                            result   = reg_y + 1;
                                            reg_y    <= result;
                                            reg_p[1] <= (result == 0);
                                            reg_p[7] <= result[7];
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_DEX: begin
                                            logic [8-1:0] result  ;
                                            result   = reg_x - 1;
                                            reg_x    <= result;
                                            reg_p[1] <= (result == 0);
                                            reg_p[7] <= result[7];
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_DEY: begin
                                            logic [8-1:0] result  ;
                                            result   = reg_y - 1;
                                            reg_y    <= result;
                                            reg_p[1] <= (result == 0);
                                            reg_p[7] <= result[7];
                                            state    <= cpu_state_t_FETCH;
                                            reg_pc   <= reg_pc + decode_entry.len;
                                        end

                                        inst_t_RTS: begin
                                            state <= cpu_state_t_RTS_PULL_LO;
                                        end

                                        default: begin
                                            state <= cpu_state_t_FETCH;
                                        end
                                    endcase
                                end
                                addr_mode_t_IMM, addr_mode_t_ZP, addr_mode_t_ZPX, addr_mode_t_ZPY, addr_mode_t_INDX,
                                addr_mode_t_INDY, addr_mode_t_REL: begin
                                    state <= cpu_state_t_OP1;
                                end

                                addr_mode_t_ABS, addr_mode_t_ABSX, addr_mode_t_ABSY, addr_mode_t_IND: begin
                                    state <= cpu_state_t_OP1;
                                end
                                default: begin
                                    state <= cpu_state_t_FETCH;
                                end
                            endcase
                        end
                    end

                    cpu_state_t_OP1: begin
                        case ((addr_mode))
                            addr_mode_t_IMM, addr_mode_t_REL: begin
                                op1   <= cpubus.rdata;
                                state <= cpu_state_t_EXEC;
                            end
                            addr_mode_t_ZP: begin
                                op1      <= cpubus.rdata;
                                eff_addr <= {8'h00, cpubus.rdata};
                                state    <= cpu_state_t_EXEC;
                            end
                            addr_mode_t_ZPX: begin
                                op1      <= cpubus.rdata;
                                eff_addr <= {8'h00, cpubus.rdata + reg_x};
                                state    <= cpu_state_t_EXEC;
                            end
                            addr_mode_t_ZPY: begin
                                op1      <= cpubus.rdata;
                                eff_addr <= {8'h00, cpubus.rdata + reg_y};
                                state    <= cpu_state_t_EXEC;
                            end
                            addr_mode_t_INDX: begin
                                op1      <= cpubus.rdata;
                                ptr_addr <= cpubus.rdata + reg_x;
                                state    <= cpu_state_t_OP2;
                            end
                            addr_mode_t_INDY: begin
                                op1      <= cpubus.rdata;
                                ptr_addr <= cpubus.rdata;
                                state    <= cpu_state_t_OP2;
                            end
                            addr_mode_t_ABS: begin
                                op1   <= cpubus.rdata;
                                state <= cpu_state_t_OP2;
                            end
                            addr_mode_t_ABSX: begin
                                op1   <= cpubus.rdata;
                                state <= cpu_state_t_OP2;
                            end
                            addr_mode_t_ABSY: begin
                                op1   <= cpubus.rdata;
                                state <= cpu_state_t_OP2;
                            end
                            addr_mode_t_IND: begin
                                op1   <= cpubus.rdata;
                                state <= cpu_state_t_OP2;
                            end
                            default: begin
                                state <= cpu_state_t_FETCH;
                            end
                        endcase
                    end

                    cpu_state_t_OP2: begin
                        case ((addr_mode))
                            addr_mode_t_INDX: begin
                                op1   <= cpubus.rdata;
                                state <= cpu_state_t_OP3;
                            end
                            addr_mode_t_INDY: begin
                                op1   <= cpubus.rdata;
                                state <= cpu_state_t_OP3;
                            end
                            addr_mode_t_ABS: begin
                                eff_addr <= {cpubus.rdata, op1};
                                if ((decoded_inst == inst_t_JMP)) begin
                                    reg_pc <= {cpubus.rdata, op1};
                                    state  <= cpu_state_t_FETCH;
                                end else begin
                                    state <= cpu_state_t_EXEC;
                                end
                            end
                            addr_mode_t_ABSX: begin
                                eff_addr <= {cpubus.rdata, op1} + reg_x;
                                state    <= cpu_state_t_EXEC;
                            end
                            addr_mode_t_ABSY: begin
                                eff_addr <= {cpubus.rdata, op1} + reg_y;
                                state    <= cpu_state_t_EXEC;
                            end
                            addr_mode_t_IND: begin
                                return_addr <= {cpubus.rdata, op1};
                                state       <= cpu_state_t_JMP_IND_LO;
                            end
                            default: begin
                                state <= cpu_state_t_FETCH;
                            end
                        endcase
                    end

                    cpu_state_t_OP3: begin
                        case ((addr_mode))
                            addr_mode_t_INDX, addr_mode_t_INDY: begin
                                if ((addr_mode == addr_mode_t_INDX)) begin
                                    eff_addr <= {cpubus.rdata, op1};
                                end else begin
                                    eff_addr <= {cpubus.rdata, op1} + reg_y;
                                end
                                state <= cpu_state_t_EXEC;
                            end
                            default: begin
                                state <= cpu_state_t_FETCH;
                            end
                        endcase
                    end

                    cpu_state_t_JMP_IND_LO: begin
                        op1 <= cpubus.rdata;
                        // 6502のJMP ($xxFF)バグ: high byteは次ページではなく同じページの$xx00から読む
                        state <= cpu_state_t_JMP_IND_HI;
                    end

                    cpu_state_t_JMP_IND_HI: begin
                        reg_pc <= {cpubus.rdata, op1};
                        state  <= cpu_state_t_FETCH;
                    end

                    cpu_state_t_EXEC: begin
                        logic [8-1:0] exec_data;
                        logic signed [16-1:0] branch_offset;
                        exec_data = ((addr_mode == addr_mode_t_IMM || addr_mode == addr_mode_t_REL) ? (
                            op1
                        ) : (
                            cpubus.rdata
                        ));
                        branch_offset = {{8{exec_data[7]}}, exec_data};
                        case ((decoded_inst))
                            // C=0なら分岐する
                            inst_t_BCC: begin
                                if ((reg_p[0] == 0)) begin
                                    reg_pc <= reg_pc + 16'd2 + branch_offset;
                                end else begin
                                    reg_pc <= reg_pc + 2;
                                end
                                state <= cpu_state_t_FETCH;
                            end

                            // C=1なら分岐する
                            inst_t_BCS: begin
                                if ((reg_p[0] == 1)) begin
                                    reg_pc <= reg_pc + 16'd2 + branch_offset;
                                end else begin
                                    reg_pc <= reg_pc + 2;
                                end
                                state <= cpu_state_t_FETCH;
                            end

                            // Z=0なら分岐する
                            inst_t_BNE: begin
                                if ((reg_p[1] == 0)) begin
                                    reg_pc <= reg_pc + 16'd2 + branch_offset;
                                end else begin
                                    reg_pc <= reg_pc + 2;
                                end
                                state <= cpu_state_t_FETCH;
                            end

                            // Z=1なら分岐する
                            inst_t_BEQ: begin
                                if ((reg_p[1] == 1)) begin
                                    reg_pc <= reg_pc + 16'd2 + branch_offset;
                                end else begin
                                    reg_pc <= reg_pc + 2;
                                end
                                state <= cpu_state_t_FETCH;
                            end

                            // N=0なら分岐する
                            inst_t_BPL: begin
                                if ((reg_p[7] == 0)) begin
                                    reg_pc <= reg_pc + 16'd2 + branch_offset;
                                end else begin
                                    reg_pc <= reg_pc + 2;
                                end
                                state <= cpu_state_t_FETCH;
                            end

                            // N=1なら分岐する
                            inst_t_BMI: begin
                                if ((reg_p[7] == 1)) begin
                                    reg_pc <= reg_pc + 16'd2 + branch_offset;
                                end else begin
                                    reg_pc <= reg_pc + 2;
                                end
                                state <= cpu_state_t_FETCH;
                            end

                            // V=0なら分岐する
                            inst_t_BVC: begin
                                if ((reg_p[6] == 0)) begin
                                    reg_pc <= reg_pc + 16'd2 + branch_offset;
                                end else begin
                                    reg_pc <= reg_pc + 2;
                                end
                                state <= cpu_state_t_FETCH;
                            end

                            // V=1なら分岐する
                            inst_t_BVS: begin
                                if ((reg_p[6] == 1)) begin
                                    reg_pc <= reg_pc + 16'd2 + branch_offset;
                                end else begin
                                    reg_pc <= reg_pc + 2;
                                end
                                state <= cpu_state_t_FETCH;
                            end

                            inst_t_JMP: begin
                                reg_pc <= eff_addr;
                                state  <= cpu_state_t_FETCH;
                            end

                            inst_t_JSR: begin
                                return_addr <= reg_pc + 16'd2;
                                reg_sp      <= reg_sp - 1;
                                state       <= cpu_state_t_JSR_PUSH_LO;
                            end

                            inst_t_PLP: begin
                                reg_p  <= exec_data | 8'h20;
                                reg_sp <= reg_sp + 1;
                                reg_pc <= reg_pc + inst_len;
                                state  <= cpu_state_t_FETCH;
                            end

                            inst_t_PLA: begin
                                reg_a    <= exec_data;
                                reg_p[1] <= (exec_data == 0);
                                reg_p[7] <= exec_data[7];
                                reg_sp   <= reg_sp + 1;
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end

                            inst_t_LDA: begin
                                reg_a    <= exec_data;
                                reg_p[1] <= (exec_data == 0);
                                reg_p[7] <= exec_data[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_LDX: begin
                                reg_x    <= exec_data;
                                reg_p[1] <= (exec_data == 0);
                                reg_p[7] <= exec_data[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_LDY: begin
                                reg_y    <= exec_data;
                                reg_p[1] <= (exec_data == 0);
                                reg_p[7] <= exec_data[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_CPX: begin
                                logic [8-1:0] result  ;
                                result   = reg_x - exec_data;
                                reg_p[0] <= (reg_x >= exec_data);
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= result[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_CPY: begin
                                logic [8-1:0] result  ;
                                result   = reg_y - exec_data;
                                reg_p[0] <= (reg_y >= exec_data);
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= result[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_CMP: begin
                                logic [8-1:0] result  ;
                                result   = reg_a - exec_data;
                                reg_p[0] <= (reg_a >= exec_data);
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= result[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_ADC: begin
                                logic [8-1:0] old_a   ;
                                logic [9-1:0] sum     ;
                                logic [8-1:0] result  ;
                                old_a    = reg_a;
                                sum      = {1'b0, old_a} + {1'b0, exec_data} + {8'h00, reg_p[0]};
                                result   = sum[7:0];
                                reg_a    <= result;
                                reg_p[0] <= sum[8];
                                reg_p[1] <= (result == 0);
                                reg_p[6] <= ((old_a ^ result) & (exec_data ^ result) & 8'h80) != 0;
                                reg_p[7] <= result[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_SBC: begin
                                logic [8-1:0] old_a   ;
                                logic [8-1:0] inv_mem ;
                                logic [9-1:0] sum     ;
                                logic [8-1:0] result  ;
                                old_a    = reg_a;
                                inv_mem  = ~exec_data;
                                sum      = {1'b0, old_a} + {1'b0, inv_mem} + {8'h00, reg_p[0]};
                                result   = sum[7:0];
                                reg_a    <= result;
                                reg_p[0] <= sum[8];
                                reg_p[1] <= (result == 0);
                                reg_p[6] <= ((old_a ^ result) & (inv_mem ^ result) & 8'h80) != 0;
                                reg_p[7] <= result[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_ORA: begin
                                logic [8-1:0] result  ;
                                result   = reg_a | exec_data;
                                reg_a    <= result;
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= result[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_INC: begin
                                logic [8-1:0] result  ;
                                result   = exec_data + 1;
                                op2      <= result;
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= result[7];
                                state    <= cpu_state_t_RMW_WRITE;
                            end
                            inst_t_DEC: begin
                                logic [8-1:0] result  ;
                                result   = exec_data - 1;
                                op2      <= result;
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= result[7];
                                state    <= cpu_state_t_RMW_WRITE;
                            end
                            inst_t_ASL: begin
                                logic [8-1:0] result  ;
                                result   = exec_data << 1;
                                op2      <= result;
                                reg_p[0] <= exec_data[7];
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= result[7];
                                state    <= cpu_state_t_RMW_WRITE;
                            end
                            inst_t_LSR: begin
                                logic [8-1:0] result  ;
                                result   = exec_data >> 1;
                                op2      <= result;
                                reg_p[0] <= exec_data[0];
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= 1'b0;
                                state    <= cpu_state_t_RMW_WRITE;
                            end
                            inst_t_ROL: begin
                                logic [8-1:0] result  ;
                                result   = {exec_data[6:0], reg_p[0]};
                                op2      <= result;
                                reg_p[0] <= exec_data[7];
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= result[7];
                                state    <= cpu_state_t_RMW_WRITE;
                            end
                            inst_t_ROR: begin
                                logic [8-1:0] result  ;
                                result   = {reg_p[0], exec_data[7:1]};
                                op2      <= result;
                                reg_p[0] <= exec_data[0];
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= result[7];
                                state    <= cpu_state_t_RMW_WRITE;
                            end
                            inst_t_AND: begin
                                logic [8-1:0] result  ;
                                result   = reg_a & exec_data;
                                reg_a    <= result;
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= result[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_EOR: begin
                                logic [8-1:0] result  ;
                                result   = reg_a ^ exec_data;
                                reg_a    <= result;
                                reg_p[1] <= (result == 0);
                                reg_p[7] <= result[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_BIT: begin
                                logic [8-1:0] result  ;
                                result   = reg_a & exec_data;
                                reg_p[1] <= (result == 0);
                                reg_p[6] <= exec_data[6];
                                reg_p[7] <= exec_data[7];
                                reg_pc   <= reg_pc + inst_len;
                                state    <= cpu_state_t_FETCH;
                            end
                            inst_t_STA: begin
                                reg_pc <= reg_pc + inst_len;
                                state  <= cpu_state_t_FETCH;
                            end
                            inst_t_STX: begin
                                reg_pc <= reg_pc + inst_len;
                                state  <= cpu_state_t_FETCH;
                            end
                            inst_t_STY: begin
                                reg_pc <= reg_pc + inst_len;
                                state  <= cpu_state_t_FETCH;
                            end
                            default: begin
                                state <= cpu_state_t_FETCH;
                            end
                        endcase
                    end
                    cpu_state_t_RMW_WRITE: begin
                        reg_pc <= reg_pc + inst_len;
                        state  <= cpu_state_t_FETCH;
                    end
                    cpu_state_t_INT_PUSH_LO: begin
                        reg_sp <= reg_sp - 1;
                        state  <= cpu_state_t_INT_PUSH_P;
                    end
                    cpu_state_t_INT_PUSH_P: begin
                        reg_sp   <= reg_sp - 1;
                        reg_p[2] <= 1'b1;
                        state    <= cpu_state_t_INT_VECTOR_LO;
                    end
                    cpu_state_t_INT_VECTOR_LO: begin
                        state <= cpu_state_t_INT_VECTOR_LO_WAIT;
                    end
                    cpu_state_t_INT_VECTOR_LO_WAIT: begin
                        op1   <= cpubus.rdata;
                        state <= cpu_state_t_INT_VECTOR_HI;
                    end
                    cpu_state_t_INT_VECTOR_HI: begin
                        state <= cpu_state_t_INT_VECTOR_HI_READ;
                    end
                    cpu_state_t_INT_VECTOR_HI_READ: begin
                        reg_pc <= {cpubus.rdata, op1};
                        state  <= cpu_state_t_FETCH;
                    end
                    cpu_state_t_JSR_PUSH_LO: begin
                        reg_sp <= reg_sp - 1;
                        reg_pc <= eff_addr;
                        state  <= cpu_state_t_FETCH;
                    end
                    cpu_state_t_RTI_PULL_P: begin
                        reg_p  <= cpubus.rdata | 8'h20;
                        reg_sp <= reg_sp + 1;
                        state  <= cpu_state_t_RTI_WAIT_LO;
                    end
                    cpu_state_t_RTI_WAIT_LO: begin
                        op1    <= cpubus.rdata;
                        reg_sp <= reg_sp + 1;
                        state  <= cpu_state_t_RTI_PULL_HI;
                    end
                    cpu_state_t_RTI_PULL_HI: begin
                        reg_sp <= reg_sp + 1;
                        reg_pc <= {cpubus.rdata, op1};
                        state  <= cpu_state_t_FETCH;
                    end
                    cpu_state_t_RTS_PULL_LO: begin
                        op1    <= cpubus.rdata;
                        reg_sp <= reg_sp + 1;
                        state  <= cpu_state_t_RTS_WAIT_HI;
                    end
                    cpu_state_t_RTS_WAIT_HI: begin
                        reg_sp <= reg_sp + 1;
                        reg_pc <= {cpubus.rdata, op1} + 16'd1;
                        state  <= cpu_state_t_FETCH;
                    end
                    default: begin
                        state <= cpu_state_t_RESET0;
                    end
                endcase
            end
        end
    end
endmodule
//# sourceMappingURL=cpu.sv.map
