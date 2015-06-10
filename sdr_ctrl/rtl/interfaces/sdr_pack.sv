//////////////////////////////////////////////////////////////////////
////                                                              ////
////    sdr_pack.sv                                               ////
////                                                              ////
//// This package houses the enums for different SDRC->SDRAM      ////
//// commands and SDRAM states. This allows the SDRC interface    ////
//// to track commands, as well as giving a testbench access      ////
//// to the various states and commands for testing assertions.   ////
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
package sdr_pack;

typedef enum logic [3:0] {
 INITIALIZING, IDLE, REFRESHING, ACTIVATING, ACTIVE, RD, RD_W_PC, WR, WR_W_PC, PRECHARGING
} bankState_t;

typedef enum logic [3:0] {
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

endpackage
