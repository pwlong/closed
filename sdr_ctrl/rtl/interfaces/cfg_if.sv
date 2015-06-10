//////////////////////////////////////////////////////////////////////
////                                                              ////
////    cfg_if.sv                                                 ////
////                                                              ////
//// The SDRC configuration interface gives an SoC/testbench      ////
//// simple access to the signals required to configure the SDRC. ////
//// It is simply a number of signals and parameters and one task ////
//// to manipulate the signals.                                   ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2015 Authors and OPENCORES.ORG                 ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

interface cfg_if ();
// pragma attribute cfg_if partition_interface_xif
   
    parameter SDR_REFRESH_TIMER_W   = 1;
    parameter SDR_REFRESH_ROW_CNT_W = 1;
    parameter CFG_SDR_WIDTH = 2'b10;
    parameter CFG_COLBITS   = 2'b00;
    parameter TWR       = 1; // Write Recovery
    parameter TRAS_D    = 4; // Active to Precharge Delay
    parameter TCAS      = 3; // CAS Latency
    parameter TRCD_D    = 2; // Active to Read or Write Delay
    parameter TRP_D     = 2; // Precharge Command Period
    parameter TRCAR_D   = 7; // Active-Active/Auto-Refresh Command Period
    parameter BURST_LEN = 3; // READ/WRITE Burst Length

    logic [1:0]   cfg_sdr_width       ; // 2'b00 - 32 Bit SDR, 2'b01 - 16 Bit SDR, 2'b1x - 8 Bit
    logic [1:0]   cfg_colbits         ; // 2'b00 - 8 Bit column address, 
    logic [3:0]   cfg_sdr_tras_d      ; // Active to precharge delay
    logic [3:0]   cfg_sdr_trp_d       ; // Precharge to active delay
    logic [3:0]   cfg_sdr_trcd_d      ; // Active to R/W delay
    logic         cfg_sdr_en          ; // Enable SDRAM controller
    logic [1:0]   cfg_req_depth       ; // Maximum Request accepted by SDRAM controller
    logic [12:0]  cfg_sdr_mode_reg    ;
    logic [2:0]   cfg_sdr_cas         ; // SDRAM CAS Latency
    logic [3:0]   cfg_sdr_trcar_d     ; // Auto-refresh period
    logic [3:0]   cfg_sdr_twr_d       ; // Write recovery delay
    logic [SDR_REFRESH_TIMER_W-1:0]   cfg_sdr_rfsh;
    logic [SDR_REFRESH_ROW_CNT_W-1:0] cfg_sdr_rfmax;
    wire sdr_init_done;
    
    
    modport master (
        output cfg_sdr_width       ,
        output cfg_colbits         ,
        output cfg_sdr_tras_d      ,
        output cfg_sdr_trp_d       ,
        output cfg_sdr_trcd_d      ,
        output cfg_sdr_en          ,
        output cfg_req_depth       ,
        output cfg_sdr_mode_reg    ,
        output cfg_sdr_cas         ,
        output cfg_sdr_trcar_d     ,
        output cfg_sdr_twr_d       ,
        output cfg_sdr_rfsh        ,
        output cfg_sdr_rfmax       ,
        input  sdr_init_done       );
        //task setup()              );

    modport slave (
        input  cfg_sdr_width       ,
        input  cfg_colbits         ,
        input  cfg_sdr_tras_d      ,
        input  cfg_sdr_trp_d       ,
        input  cfg_sdr_trcd_d      ,
        input  cfg_sdr_en          ,
        input  cfg_req_depth       ,
        input  cfg_sdr_mode_reg    ,
        input  cfg_sdr_cas         ,
        input  cfg_sdr_trcar_d     ,
        input  cfg_sdr_twr_d       ,
        input  cfg_sdr_rfsh        ,
        input  cfg_sdr_rfmax       ,
        output sdr_init_done
    );
    
    
    task setup(); // pragma tbx xtf
      cfg_sdr_width    <= CFG_SDR_WIDTH;
      cfg_colbits      <= CFG_COLBITS  ;
      cfg_sdr_mode_reg[2:0]   <= BURST_LEN;  // Burst Length
      cfg_sdr_mode_reg[3]     <= 0 ;         // Burst Type
      cfg_sdr_mode_reg[6:4]   <= TCAS;       // CAS Delay
      cfg_sdr_mode_reg[8:7]   <= 0 ;         // OP Mode
      cfg_sdr_mode_reg[9]     <= 0 ;         // Write Burst mode
      cfg_sdr_mode_reg[12:10] <= 0 ;         // Reserved
      cfg_sdr_tras_d   <=  TRAS_D  ;
      cfg_sdr_trp_d    <=  TRP_D   ;
      cfg_sdr_trcd_d   <=  TRCD_D  ;
      cfg_sdr_cas      <=  TCAS    ;
      cfg_sdr_trcar_d  <=  TRCAR_D ;
      cfg_sdr_twr_d    <=  TWR     ;
      cfg_sdr_rfsh     <=  12'h100 ;
      cfg_sdr_rfmax    <=  3'h6    ;
      cfg_req_depth    <=  2'h3    ;
      cfg_sdr_en       <=  1'b1    ;
    endtask
    

endinterface
