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
  wishbone_interface.master wbi,
  sdr_bus                   sdram_bus,
  cfg_if.slave              cfg
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
wire [dw-1:0]         app_rd_data        ; // sdr read data

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

    sdrc_core #(.SDR_DW(SDR_DW) , .SDR_BW(SDR_BW), .APP_RW(APP_RW)) u_sdrc_core (
        .clk                (sdram_bus.sdram_clk    ) ,
        .pad_clk            (sdram_pad_clk          ) ,
        .reset_n            (sdram_bus.sdram_resetn ) ,
    
		/* Request from app */
        .app_req            (app_req            ) ,// Transfer Request
        .app_req_addr       (app_req_addr       ) ,// SDRAM Address
        .app_req_len        (app_req_len        ) ,// Burst Length (in 16 bit words)
        .app_req_wrap       (1'b0               ) ,// Wrap mode request 
        .app_req_wr_n       (app_req_wr_n       ) ,// 0 => Write request, 1 => read req
        .app_req_ack        (app_req_ack        ) ,// Request has been accepted
     		
        .app_wr_data        (app_wr_data        ) ,
        .app_wr_en_n        (app_wr_en_n        ) ,
        .app_rd_data        (app_rd_data        ) ,
        .app_rd_valid       (app_rd_valid       ) ,
        .app_last_rd        (app_last_rd        ) ,
        .app_last_wr        (app_last_wr        ) ,
        .app_wr_next_req    (app_wr_next_req    ) ,
        .app_req_dma_last   (app_req            ) ,
 
 		/* Interface to SDRAMs */
        .sdram_bus(sdram_bus),
        /* Configuration Bus */
        .cfg                (cfg                )
    );
        
endmodule // sdrc_core
