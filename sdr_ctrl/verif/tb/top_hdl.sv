//////////////////////////////////////////////////////////////////////
////                                                              ////
////    top_hdl.sv                                                ////
////                                                              ////
//// HDL instantiates all modules and interfaces for testing the  ////
//// DUT                                                          ////
////    modules                                                   ////
////        - sdrc_top - this is the top level SDRAM controller   ////
////        - DIMM - a memory stub for the SDRC to interact with  ////
////    interfaces                                                ////
////        - wishbone_interface - allows testbench/HVL to        ////
////          communicate with the SDRC                           ////
////        - cfg_if - allows testbench to set up the SDRC        ////
////        - sdr_bus - interface between SDRC and SDRAM          ////
//// The HDL also houses the clocks for the DUT - this is         ////
//// required by Veloce                                           ////
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

`include "../../rtl/core/sdrc_define.v"
`include "top_defines.sv"
`timescale 1ns/1ps
// this is the emulation side of Veloce 
// it instantiates all modules, connects them up, and generates the system wide clock
module top_hdl();	//pragma attribute top_hdl partition_module_xrtl

    // WIRE DECLARATIONS
    logic sys_clk,sdram_clk,sdram_clk_d,RESETN;
    logic sdr_init_done;

    // INTERFACE DECLARATIONS
    wishbone_interface #(.data_width(dw)
    ) wbi(   .wb_clk_i(sys_clk),
             .wb_rst_i(!RESETN),
             .wb_sdram_clk_i(sdram_clk)
    );

    cfg_if #(.SDR_REFRESH_TIMER_W(`SDR_RFSH_TIMER_W),
             .SDR_REFRESH_ROW_CNT_W(`SDR_RFSH_ROW_CNT_W),
             .CFG_SDR_WIDTH(CFG_SDR_WIDTH),
             .CFG_COLBITS(CFG_COLBITS),
             .TWR(TWR),
             .TRAS_D(TRAS_D),
             .TCAS(TCAS),
             .TRCD_D(TRCD_D),
             .TRP_D(TRP_D),
             .TRCAR_D(TRCAR_D),
             .BURST_LEN(BURST_LEN)
    ) cfg();

    sdr_bus #(.SDR_DW(SDR_DW),
              .SDR_BW(SDR_BW),
              .BURST_LENGTH(BURST_LEN),
              .TRAS(TRAS_D),
              .TCAS(TCAS),
              .TRCD(TRCD_D),
              .TRP(TRP_D),
              .TWR(TWR)
    ) sdram_bus (.sdram_clk,
                 .sdram_clk_d,
                 .sdram_resetn(RESETN),
                 .sdr_init_done(cfg.sdr_init_done)
    );

    // TOP LEVEL
    sdrc_top #(
        .SDR_DW(SDR_DW),
        .SDR_BW(SDR_BW)
    ) u_dut (
        // wishbone interface
        wbi.master,
        // sdram interface
        sdram_bus.ctrlcore,
        // configuration bus
        cfg.slave
    );

    // DIMM MODEL
    `ifdef SDR_32BIT
    mt48lc2m32b2 #(.data_bits(32)) u_sdram32 (.sdram_bus(sdram_bus));
    `elsif SDR_16BIT
    IS42VM16400K u_sdram16 (.sdram_bus(sdram_bus));
    `else
    mt48lc8m8a2 #(.data_bits(8)) u_sdram8 (.sdram_bus(sdram_bus));
    `endif


    // clocks
    // tbx clkgen
    initial begin
        sys_clk = 0;
        forever begin
            #(P_SYS/2) sys_clk = ~sys_clk;
        end
    end
    
    // tbx clkgen
    initial begin
        sdram_clk = 0;
        forever begin
            #(P_SDR/2) sdram_clk = ~sdram_clk;
        end
    end
    
    // to fix the sdram interface timing issue
    assign  #(2.0) sdram_clk_d   = sdram_clk;

    // reset
    // tbx clkgen
    initial begin
        RESETN = 1;
        #100;
        RESETN = 0; // apply reset
        #10000;
        RESETN = 1;
        #1000;
    end
        
/* PWL testing getting veloce running
   initial begin
       wbi.wb_addr_i      = 0;
       wbi.wb_dat_i       = 0;
       wbi.wb_sel_i       = 4'h0;
       wbi.wb_we_i        = 0;
       wbi.wb_stb_i       = 0;
       wbi.wb_cyc_i       = 0;
    end
*/


endmodule
