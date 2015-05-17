/*********************************************************************
                                                              
  SDRAM Controller top File                                  
                                                              
  This file is part of the sdram controller project           
  http://www.opencores.org/cores/sdr_ctrl/                    
                                                              
  Description: SDRAM Controller Top Module.
    Support 81/6/32 Bit SDRAM.
    Column Address is Programmable
    Bank Bit are 2 Bit
    Row Bits are 12 Bits

    This block integrate following sub modules

    sdrc_core   
        SDRAM Controller file
    wb2sdrc    
        This module translate the bus protocol from wishbone to customers
        dram controller
                                                              
  To Do:                                                      
    nothing                                                   
                                                              
  Author(s): Dinesh Annayya, dinesha@opencores.org                 
  Version  : 0.0 - 8th Jan 2012
                Initial version with 16/32 Bit SDRAM Support
           : 0.1 - 24th Jan 2012
	         8 Bit SDRAM Support is added
	     0.2 - 31st Jan 2012
	         sdram_dq and sdram_pad_clk are internally generated
	     0.3 - 26th April 2013
                  Sdram Address width is increased from 12 to 13bits

                                                             
 Copyright (C) 2000 Authors and OPENCORES.ORG                
                                                             
 This source file may be used and distributed without         
 restriction provided that this copyright statement is not    
 removed from the file and that any derivative work contains  
 the original copyright notice and the associated disclaimer. 
                                                              
 This source file is free software; you can redistribute it   
 and/or modify it under the terms of the GNU Lesser General   
 Public License as published by the Free Software Foundation; 
 either version 2.1 of the License, or (at your option) any   
later version.                                               
                                                              
 This source is distributed in the hope that it will be       
 useful, but WITHOUT ANY WARRANTY; without even the implied   
 warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
 PURPOSE.  See the GNU Lesser General Public License for more 
 details.                                                     
                                                              
 You should have received a copy of the GNU Lesser General    
 Public License along with this source; if not, download it   
 from http://www.opencores.org/lgpl.shtml                     
                                                              
*******************************************************************/
`timescale 1ns/1ps

`include "sdrc_define.v"
module sdrc_top 
#(
  parameter APP_AW   = 26,  // Application Address Width
  parameter APP_DW   = 32,  // Application Data Width 
  parameter APP_BW   = 4,   // Application Byte Width
  parameter APP_RW   = 9,   // Application Request Width
            
  parameter SDR_DW   = 16,  // SDR Data Width 
  parameter SDR_BW   = 2,   // SDR Byte Width
            
  parameter dw       = 32,  // data width
  parameter tw       = 8,   // tag id width
  parameter bl       = 9    // burst_lenght_width 
)
( 
  //-----------------------------------------------
  // Global Variable
  // ----------------------------------------------
  input [1:0] cfg_sdr_width      , // 2'b00 - 32 Bit SDR, 2'b01 - 16 Bit SDR, 2'b1x - 8 Bit
  input [1:0] cfg_colbits        , // 2'b00 - 8 Bit column address, 
                                              // 2'b01 - 9 Bit, 10 - 10 bit, 11 - 11Bits
  wishbone_interface.master wbi,
  //--------------------------------------
  // Wish Bone Interface
  // -------------------------------------      
 /*
  input                   wb_rst_i           ,
  input                   wb_clk_i           ,
  
  input                   wb_stb_i           ,
  output                  wb_ack_o           ,
  input  [APP_AW-1:0]     wb_addr_i          ,
  input                   wb_we_i            , // 1 - Write, 0 - Read
  input  [dw-1:0]         wb_dat_i           ,
  input  [dw/8-1:0]       wb_sel_i           , // Byte enable
  output [dw-1:0]         wb_dat_o           ,
  input                   wb_cyc_i           ,
  input  [2:0]            wb_cti_i           ,
  */
  //------------------------------------------------
  // Interface to SDRAMs
  //------------------------------------------------
  //sdr_bus.ctrl sdram_bus,
  sdr_bus sdram_bus,
  /* using the interface we designed so we don't need these PWL
  output                  sdr_cke             , // SDRAM Clock Enable
  output 			sdr_cs_n            , // SDRAM Chip Select
  output                  sdr_ras_n           , // SDRAM ras
  output                  sdr_cas_n           , // SDRAM cas
  output			sdr_we_n            , // SDRAM write enable
  output [SDR_BW-1:0] 	sdr_dqm             , // SDRAM Data Mask
  output [1:0] 		sdr_ba              , // SDRAM Bank Enable
  output [12:0] 		sdr_addr            , // SDRAM Address
  inout [SDR_DW-1:0] 	sdr_dq              , // SDRA Data Input/output
  */
  
  //------------------------------------------------
  // Configuration Parameter
  //------------------------------------------------
  output          sdr_init_done       , // Indicate SDRAM Initialisation Done
  input   [3:0]   cfg_sdr_tras_d      , // Active to precharge delay
  input   [3:0]   cfg_sdr_trp_d       , // Precharge to active delay
  input   [3:0]   cfg_sdr_trcd_d      , // Active to R/W delay
  input   			  cfg_sdr_en          , // Enable SDRAM controller
  input   [1:0] 	cfg_req_depth       , // Maximum Request accepted by SDRAM controller
  input   [12:0] 	cfg_sdr_mode_reg    ,
  input   [2:0] 	cfg_sdr_cas         , // SDRAM CAS Latency
  input   [3:0] 	cfg_sdr_trcar_d     , // Auto-refresh period
  input   [3:0]   cfg_sdr_twr_d       , // Write recovery delay
  input   [`SDR_RFSH_TIMER_W-1:0]   cfg_sdr_rfsh,
  input   [`SDR_RFSH_ROW_CNT_W-1:0] cfg_sdr_rfmax
);
//--------------------------------------------
// SDRAM controller Interface 
//--------------------------------------------
wire                  app_req            ; // SDRAM request
wire [APP_AW-1:0]     app_req_addr       ; // SDRAM Request Address
wire [bl-1:0]         app_req_len        ;
wire                  app_req_wr_n       ; // 0 - Write, 1 -> Read
wire                  app_req_ack        ; // SDRAM request Accepted
wire                  app_busy_n         ; // 0 -> sdr busy
wire [dw/8-1:0]       app_wr_en_n        ; // Active low sdr byte-wise write data valid
wire                  app_wr_next_req    ; // Ready to accept the next write
wire                  app_rd_valid       ; // sdr read valid
wire                  app_last_rd        ; // Indicate last Read of Burst Transfer
wire                  app_last_wr        ; // Indicate last Write of Burst Transfer
wire [dw-1:0]         app_wr_data        ; // sdr write data
wire  [dw-1:0]        app_rd_data        ; // sdr read data

/****************************************
*  These logic has to be implemented using Pads
*  **************************************/
wire  [SDR_DW-1:0]    pad_sdr_din         ; // SDRA Data Input
wire  [SDR_DW-1:0]    sdr_dout            ; // SDRAM Data Output
wire  [SDR_BW-1:0]    sdr_den_n           ; // SDRAM Data Output enable


assign   sdram_bus.sdr_dq = (&sdr_den_n == 1'b0) ? sdr_dout :  {SDR_DW{1'bz}}; 
assign   pad_sdr_din = sdram_bus.sdr_dq;

// sdram pad clock is routed back through pad
// SDRAM Clock from Pad, used for registering Read Data
wire #(1.0) sdram_pad_clk = sdram_bus.sdram_clk;

/************** Ends Here **************************/
wb2sdrc #(.dw(dw),.tw(tw),.bl(bl)) u_wb2sdrc (
      // WB bus
      .wbi(wbi),

      //SDRAM Controller Hand-Shake Signal 
          .sdram_clk          (sdram_bus.sdram_clk          ) ,
          .sdram_resetn       (sdram_bus.sdram_resetn       ) ,
          .sdr_req            (app_req            ) ,
          .sdr_req_addr       (app_req_addr       ) ,
          .sdr_req_len        (app_req_len        ) ,
          .sdr_req_wr_n       (app_req_wr_n       ) ,
          .sdr_req_ack        (app_req_ack        ) ,
          .sdr_busy_n         (app_busy_n         ) ,
          .sdr_wr_en_n        (app_wr_en_n        ) ,
          .sdr_wr_next        (app_wr_next_req    ) ,
          .sdr_rd_valid       (app_rd_valid       ) ,
          .sdr_last_rd        (app_last_rd        ) ,
          .sdr_wr_data        (app_wr_data        ) ,
          .sdr_rd_data        (app_rd_data        ) 

      ); 


sdrc_core #(.SDR_DW(SDR_DW) , .SDR_BW(SDR_BW)) u_sdrc_core (
          .clk                (sdram_bus.sdram_clk          ) ,
          .pad_clk            (sdram_pad_clk      ) ,
          .reset_n            (sdram_bus.sdram_resetn       ) ,
          .sdr_width          (cfg_sdr_width      ) ,
          .cfg_colbits        (cfg_colbits        ) ,

 		/* Request from app */
          .app_req            (app_req            ) ,// Transfer Request
          .app_req_addr       (app_req_addr       ) ,// SDRAM Address
          .app_req_len        (app_req_len        ) ,// Burst Length (in 16 bit words)
          .app_req_wrap       (1'b0               ) ,// Wrap mode request 
          .app_req_wr_n       (app_req_wr_n       ) ,// 0 => Write request, 1 => read req
          .app_req_ack        (app_req_ack        ) ,// Request has been accepted
          .cfg_req_depth      (cfg_req_depth      ) ,//how many req. buffer should hold
 		
          .app_wr_data        (app_wr_data        ) ,
          .app_wr_en_n        (app_wr_en_n        ) ,
          .app_rd_data        (app_rd_data        ) ,
          .app_rd_valid       (app_rd_valid       ) ,
	  .app_last_rd        (app_last_rd        ) ,
          .app_last_wr        (app_last_wr        ) ,
          .app_wr_next_req    (app_wr_next_req    ) ,
          .sdr_init_done      (sdr_init_done      ) ,
          .app_req_dma_last   (app_req            ) ,
 
 		/* Interface to SDRAMs */
          .sdr_cs_n           (sdram_bus.sdr_cs_n ) ,
          .sdr_cke            (sdram_bus.sdr_cke  ) ,
          .sdr_ras_n          (sdram_bus.sdr_ras_n) ,
          .sdr_cas_n          (sdram_bus.sdr_cas_n) ,
          .sdr_we_n           (sdram_bus.sdr_we_n ) ,
          .sdr_dqm            (sdram_bus.sdr_dqm  ) ,
          .sdr_ba             (sdram_bus.sdr_ba   ) ,
          .sdr_addr           (sdram_bus.sdr_addr ) , 
          .pad_sdr_din        (pad_sdr_din        ) ,
          .sdr_dout           (sdr_dout           ) ,
          .sdr_den_n          (sdr_den_n          ) ,
 
 		/* Parameters */
          .cfg_sdr_en         (cfg_sdr_en         ) ,
          .cfg_sdr_mode_reg   (cfg_sdr_mode_reg   ) ,
          .cfg_sdr_tras_d     (cfg_sdr_tras_d     ) ,
          .cfg_sdr_trp_d      (cfg_sdr_trp_d      ) ,
          .cfg_sdr_trcd_d     (cfg_sdr_trcd_d     ) ,
          .cfg_sdr_cas        (cfg_sdr_cas        ) ,
          .cfg_sdr_trcar_d    (cfg_sdr_trcar_d    ) ,
          .cfg_sdr_twr_d      (cfg_sdr_twr_d      ) ,
          .cfg_sdr_rfsh       (cfg_sdr_rfsh       ) ,
          .cfg_sdr_rfmax      (cfg_sdr_rfmax      ) 
	       );
        
    // update interface's storage of state of each bank
    assign sdram_bus.bank_st[0] = u_sdrc_core.u_bank_ctl.bank0_fsm.bank_st;
    assign sdram_bus.bank_st[1] = u_sdrc_core.u_bank_ctl.bank1_fsm.bank_st;
    assign sdram_bus.bank_st[2] = u_sdrc_core.u_bank_ctl.bank2_fsm.bank_st;
    assign sdram_bus.bank_st[3] = u_sdrc_core.u_bank_ctl.bank3_fsm.bank_st;
   
endmodule // sdrc_core
