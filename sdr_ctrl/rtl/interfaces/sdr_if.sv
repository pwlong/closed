interface sdr_bus #(
  parameter  SDR_DW   = 16,         // SDRAM Data Width 
  parameter  SDR_BW   = 2           // SDRAM Byte Width
  )(
  input logic sdram_clk,                 // SDRAM Clock
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
    input sdram_clk,
    input sdram_resetn
  );

endinterface
