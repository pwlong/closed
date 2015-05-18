interface sdr_bus #(
  parameter  SDR_DW   = 16,         // SDRAM Data Width 
  parameter  SDR_BW   = 2           // SDRAM Byte Width
  )(
  input logic sdram_clk,                 // SDRAM Clock
  input logic sdram_clk_d,               // Delayed clock
  input logic sdram_resetn
);
  logic               sdr_cke;      // SDRAM Clock
  logic               sdr_cs_n;     // SDRAM Chip Select
  logic 	          sdr_ras_n;    // SDRAM ras
  logic 	          sdr_cas_n;    // SDRAM cas
  logic 	          sdr_we_n;     // SDRAM write enable
  wire [SDR_DW-1:0]  sdr_dq;       // SDRAM DATA                               
  logic [SDR_BW-1:0]  sdr_dqm;      // SDRAM Data Mask
  logic [1:0]         sdr_ba;       // SDRAM Bank Enable
  logic [12:0] 		  sdr_addr;     // SDRAM Address
  logic [SDR_DW-1:0]  sdr_din;  // SDRAM Data Input
  logic [SDR_DW-1:0]  sdr_dout;     // SDRAM Data Output
  logic [SDR_BW-1:0]  sdr_den_n;    // SDRAM Data Output enable

  // Tristate logic for the din/dout pins on the core
  assign   sdr_dq = (&sdr_den_n == 1'b0) ? sdr_dout :  {SDR_DW{1'bz}};
  assign   sdr_din = sdr_dq;

  modport ctrltop (
    inout  sdr_dq,
    output sdr_addr,
    output sdr_ba,
    output sdr_cke,
    output sdr_cs_n,
    output sdr_ras_n,
    output sdr_cas_n,
    output sdr_we_n,
    output sdr_dqm,
    input  sdram_clk,
    input  sdram_resetn
  );

  modport ctrlcore (
    output sdr_addr,
    output sdr_ba,
    output sdr_cke,
    output sdr_cs_n,
    output sdr_ras_n,
    output sdr_cas_n,
    output sdr_we_n,
    output sdr_dqm,
    output sdr_dout,
    output sdr_den_n,
    input  sdr_din,
    input  sdram_clk,
    input  sdram_resetn
  );
  
  modport ram (
    inout sdr_dq,
    input sdr_addr,
    input sdr_ba,
    input sdr_cke,
    input sdr_cs_n,
    input sdr_ras_n,
    input sdr_cas_n,
    input sdr_we_n,
    input sdr_dqm,
    input sdram_clk_d,
    input sdram_resetn
  );
// states from sdrc_bank_fsm.v - TODO: define these in a SINGLE place
  typedef enum bit [3:0] {
    BANK_IDLE,
    BANK_PRE,
    BANK_ACT,
    BANK_XFR,
    BANK_DMA_LAST_PRE
  } bankState_t;
  
  // commands in table 14, page 25 of dram datasheet
  typedef enum bit [3:0] {
    CMD_LOAD_MODE_REGISTER = 4'b0000,
    CMD_AUTO_REFRESH       = 4'b0001,
    CMD_PRECHARGE          = 4'b0010,
    CMD_ACTIVE             = 4'b0011,
    CMD_WRITE              = 4'b0100,
    CMD_READ               = 4'b0101,
    CMD_BURST_TERMINATE    = 4'b0110,
    CMD_NOP                = 4'b0111,
    CMD_NOP_I              = 4'b1000,
    CMD_NOP_II             = 4'b1001,
    CMD_NOP_III            = 4'b1010,
    CMD_NOP_IV             = 4'b1011,
    CMD_NOP_V              = 4'b1100,
    CMD_NOP_VI             = 4'b1101,
    CMD_NOP_VII            = 4'b1110,
    CMD_NOP_VIII           = 4'b1111
  } cmd_t;
  
  // store the state of each bank
  bankState_t [3:0] bank_st;
  
  //Current Command
  cmd_t cmd;
  assign cmd  = cmd_t'({sdr_cs_n, sdr_ras_n, sdr_cas_n, sdr_we_n});
  
  //Acceptable Commands
  bit cmd_nop;
  bit cmd_idle;
  bit cmd_act;
  bit cmd_xfr;
  assign cmd_nop   = (cmd[3] === 1'b1 | cmd === CMD_NOP);
  assign cmd_idle  = (cmd[3] === 1'b1 | cmd === CMD_NOP | cmd === CMD_ACTIVE | cmd === CMD_AUTO_REFRESH | cmd === CMD_LOAD_MODE_REGISTER | cmd === CMD_PRECHARGE);
  assign cmd_act   = (cmd[3] === 1'b1 | cmd === CMD_NOP | cmd === CMD_READ | cmd === CMD_WRITE | cmd === CMD_PRECHARGE);
  assign cmd_xfr   = (cmd[3] === 1'b1 | cmd === CMD_NOP | cmd === CMD_READ | cmd === CMD_WRITE | cmd === CMD_PRECHARGE | cmd === CMD_BURST_TERMINATE);
   
   initial begin
    //$monitor("%d", cmd);
   end
  
  always@ (posedge sdram_clk) begin
    //Bank 0 Asserts
    if (sdr_ba === 2'b00) begin
        case (bank_st[0])
            BANK_IDLE: doCommandAssert(bank_st[0],cmd_idle);
            BANK_PRE: doCommandAssert(bank_st[0],cmd_nop);
            BANK_ACT: doCommandAssert(bank_st[0],cmd_act);
            BANK_XFR: doCommandAssert(bank_st[0],cmd_xfr);
            BANK_DMA_LAST_PRE: begin
                //ignore??
            end
            default: begin
                //ignore??
            end        
        endcase
    end
  end

  task doCommandAssert(bankState_t bankState, bit [3:0] cmdIsLegal);
    begin
        assert(cmdIsLegal)
            $display("COMMAND ASSERTION PASS - STATE: %p   COMMAND: %p", bankState, cmd);
        else
            $display("COMMAND ASSERTION FAIL - STATE: %p   COMMAND: %p", bankState, cmd);
    end
  endtask
  
endinterface
