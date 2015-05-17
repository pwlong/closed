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
  `define BANK_IDLE         3'b000
  `define BANK_PRE          3'b001
  `define BANK_ACT          3'b010
  `define BANK_XFR          3'b011
  `define BANK_DMA_LAST_PRE 3'b100
  
  // commands in table 14, page 25 of dram datasheet
  `define CMD_NOP_I              4'b1xxx
  `define CMD_NOP                4'b0111
  `define CMD_ACTIVE             4'b0011
  `define CMD_READ               4'b0101
  `define CMD_WRITE              4'b0100
  `define CMD_BURST_TERMINATE    4'b0110
  `define CMD_PRECHARGE          4'b0010
  `define CMD_AUTO_REFRESH       4'b0001
  `define CMD_LOAD_MODE_REGISTER 4'b0000

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
  wire [3:0] [2:0] bank_st;
  
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
    case (bank_st[0])
        `BANK_IDLE: begin
            $display("Bank is IDLE");
            BANK_IDLE_assert: assert(cmd_idle) begin
                $display("BANK_IDLE PASS: COMMAND: %p, CMDVAR: %b", cmd, cmd_idle);
            end else begin
                $display("BANK_IDLE FAILURE: COMMAND: %p, CMDVAR: %b", cmd, cmd_idle);
            end
        end
        `BANK_PRE: begin
            $display("Bank is PRECHARGED");
            BANK_PRE_assert: assert(cmd_nop) begin
                $display("BANK_PRE PASS: COMMAND: %p, CMDVAR: %b", cmd, cmd_nop);
            end else begin
                $display("BANK_PRE FAILURE: COMMAND: %p, CMDVAR: %b", cmd, cmd_nop);
            end
        end
        `BANK_ACT: begin
            $display("Bank is ACTIVATED");
            BANK_ACT_assert: assert(cmd_act) begin
                $display("BANK_ACT_assert PASS: COMMAND: %p, CMDVAR: %b", cmd, cmd_act);
            end else begin
                $display("BANK_ACT_assert FAILURE: COMMAND: %p, CMDVAR: %b", cmd, cmd_act);
            end
        end
        `BANK_XFR: begin
            $display("Bank is XFER");
            BANK_XFR_assert: assert(cmd_xfr) begin
                $display("BANK_XFR_assert PASS: COMMAND: %p, CMDVAR: %b", cmd, cmd_xfr);
            end else begin
                $display("BANK_XFR_assert FAILURE: COMMAND: %p, CMDVAR: %b", cmd, cmd_xfr);
            end
        end
        `BANK_DMA_LAST_PRE: begin
            //ignore??
        end
        default: begin
            //ignore??
        end        
    endcase
    
    
  end
  
endinterface
