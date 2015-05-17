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
  //logic [SDR_DW-1:0] 	pad_sdr_din;  // SDRAM Data Input
  //logic [SDR_DW-1:0] 	sdr_dout;     // SDRAM Data Output
  //logic [SDR_BW-1:0] 	sdr_den_n;    // SDRAM Data Output enable

  modport ctrl (
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

  // commands in table 14, page 25 of dram datasheet
  `define CMD_NOP_I              4'b1000
  `define CMD_NOP                4'b0111
  `define CMD_ACTIVE             4'b0011
  `define CMD_READ               4'b0101
  `define CMD_WRITE              4'b0100
  `define CMD_BURST_TERMINATE    4'b0110
  `define CMD_PRECHARGE          4'b0010
  `define CMD_AUTO_REFRESH       4'b0001
  `define CMD_LOAD_MODE_REGISTER 4'b0000
  bit [3:0] cmd = {sdr_cs_n, sdr_ras_n, sdr_cas_n, sdr_we_n};
  bit cmd_idle  = (cmd === `CMD_NOP_I || cmd === `CMD_NOP || cmd === `CMD_ACTIVE || cmd === `CMD_AUTO_REFRESH || cmd === `CMD_LOAD_MODE_REGISTER || cmd === `CMD_PRECHARGE);
  bit cmd_act   = (cmd === `CMD_NOP_I || cmd === `CMD_NOP || cmd === `CMD_READ || cmd === `CMD_WRITE || cmd === `CMD_PRECHARGE);
  bit cmd_xfr   = (cmd_act || cmd === `CMD_BURST_TERMINATE);
  
  // store the state of each bank
  wire [3:0] [2:0] bank_st;
  // states from sdrc_bank_fsm.v - TODO: define these in a SINGLE place
  `define BANK_IDLE         3'b000
  `define BANK_PRE          3'b001
  `define BANK_ACT          3'b010
  `define BANK_XFR          3'b011
  `define BANK_DMA_LAST_PRE 3'b100
  
  sequence bank0_idle;
    bank_st[0] === `BANK_IDLE && sdr_ba === 2'b00 && cmd_idle;
  endsequence
  
  sequence bank0_act;
    bank_st[0] === `BANK_ACT && sdr_ba === 2'b00 && cmd_act;
  endsequence
  
  sequence bank0_xfr;
    bank_st[0] === `BANK_XFR && sdr_ba === 2'b00 && cmd_xfr;
  endsequence
  
  
  sequence bank1_idle;
    bank_st[1] === `BANK_IDLE && sdr_ba === 2'b01 && cmd_idle;
  endsequence
  
  sequence bank1_act;
    bank_st[1] === `BANK_ACT && sdr_ba === 2'b01 && cmd_act;
  endsequence
  
  sequence bank1_xfr;
    bank_st[1] === `BANK_XFR && sdr_ba === 2'b01 && cmd_xfr;
  endsequence
  
  
  sequence bank2_idle;
    bank_st[2] === `BANK_IDLE && sdr_ba === 2'b10 && cmd_idle;
  endsequence
  
  sequence bank2_act;
    bank_st[2] === `BANK_ACT && sdr_ba === 2'b10 && cmd_act;
  endsequence
  
  sequence bank2_xfr;
    bank_st[2] === `BANK_XFR && sdr_ba === 2'b10 && cmd_xfr;
  endsequence
  
  
  sequence bank3_idle;
    bank_st[3] === `BANK_IDLE && sdr_ba === 2'b11 && cmd_idle;
  endsequence
  
  sequence bank3_act;
    bank_st[3] === `BANK_ACT && sdr_ba === 2'b11 && cmd_act;
  endsequence
  
  sequence bank3_xfr;
    bank_st[3] === `BANK_XFR && sdr_ba === 2'b11 && cmd_xfr;
  endsequence

endinterface
