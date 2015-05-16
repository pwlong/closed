interface sdr_bus #(
  parameter  SDR_DW   = 16,         // SDRAM Data Width 
  parameter  SDR_BW   = 2           // SDRAM Byte Width
  )(
  input bit sdr_cke                 // SDRAM clock
);
  logic               sdr_cs_n;     // SDRAM Chip Select
	logic 	            sdr_ras_n;    // SDRAM ras
	logic 	            sdr_cas_n;    // SDRAM cas
	logic 	            sdr_we_n;     // SDRAM write enable
                                 
  logic [SDR_BW-1:0] 	sdr_dqm;      // SDRAM Data Mask
  logic [1:0] 		    sdr_ba;       // SDRAM Bank Enable
  logic [12:0] 		    sdr_addr;     // SDRAM Address
  logic [SDR_DW-1:0] 	pad_sdr_din;  // SDRAM Data Input
  logic [SDR_DW-1:0] 	sdr_dout;     // SDRAM Data Output
  logic [SDR_BW-1:0] 	sdr_den_n;    // SDRAM Data Output enable

  modport ctrl (
    output  sdr_cs_n,
    output  sdr_ras_n,
    output  sdr_cas_n,
    output  sdr_we_n,
    output  sdr_dqm,
    output  sdr_ba,
    output  sdr_addr,
    input   pad_sdr_din,
    output  sdr_dout,
    output  sdr_den_n
  );
  
  modport ram (
    input   sdr_cs_n,
    input   sdr_ras_n,
    input   sdr_cas_n,
    input   sdr_we_n,
    input   sdr_dqm,
    input   sdr_ba,
    input   sdr_addr,
    output  pad_sdr_din,
    input   sdr_dout,
    input   sdr_den_n
  );

endinterface