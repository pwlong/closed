// DEFINE TEST PARAMETERS
parameter dw = 32; // application data width
parameter tw = 8;  // tag id width
`ifdef SDR_32BIT
parameter    SDR_DW          = 32;           // SDRAM Data Width
parameter    CFG_SDR_WIDTH   = 2'b00;
`elsif SDR_16BIT
parameter    SDR_DW          = 16;           // SDRAM Data Width
parameter    CFG_SDR_WIDTH   = 2'b01;
`else  // 8 BIT SDRAM
parameter    SDR_DW          = 08;           // SDRAM Data Width
parameter    CFG_SDR_WIDTH   = 2'b10;
`endif
parameter    SDR_BW          = (SDR_DW / 8); // SDRAM Byte Width
parameter    CFG_COLBITS     = 2'b00;        // 8 Bit Column Address

// Some test timing parameters
parameter TWR       = 1; // Write Recovery
parameter TRAS_D    = 4; // Active to Precharge Delay
parameter TCAS      = 3; // CAS Latency
parameter TRCD_D    = 2; // Active to Read or Write Delay
parameter TRP_D     = 2; // Precharge Command Period
parameter TRCAR_D   = 7; // Active-Active/Auto-Refresh Command Period
parameter BURST_LEN = dw/SDR_DW; // READ/WRITE Burst Length
parameter P_SYS     = 10;     //    200MHz
parameter P_SDR     = 20;     //    100MHz
