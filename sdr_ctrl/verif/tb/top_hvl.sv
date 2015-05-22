//////////////////////////////////////////////////////////////////////
////                                                              ////
////                                                              ////
////  This file is part of the SDRAM Controller project           ////
////  http://www.opencores.org/cores/sdr_ctrl/                    ////
////                                                              ////
////  Description                                                 ////
////  SDRAM CTRL definitions.                                     ////
////                                                              ////
////  To Do:                                                      ////
////    nothing                                                   ////
////                                                              ////
//   Version  :0.1 - Test Bench automation is improvised with     ////
//             seperate data,address,burst length fifo.           ////
//             Now user can create different write and            ////
//             read sequence                                      ////
//                                                                ////
////  Author(s):                                                  ////
////      - Dinesh Annayya, dinesha@opencores.org                 ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2000 Authors and OPENCORES.ORG                 ////
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


`timescale 1ns/1ps

// This testbench verify with SDRAM TOP

module top_hvl #(
    parameter P_SYS  = 10,     //    200MHz
    parameter P_SDR  = 20,     //    100MHz
    parameter CFG_SDR_WIDTH = 2'b10,
    parameter CFG_COLBITS   = 2'b00,
    parameter TWR       = 1, // Write Recovery
    parameter TRAS_D    = 4, // Active to Precharge Delay
    parameter TCAS      = 3, // CAS Latency
    parameter TRCD_D    = 2, // Active to Read or Write Delay
    parameter TRP_D     = 2, // Precharge Command Period
    parameter TRCAR_D   = 7, // Active-Active/Auto-Refresh Command Period
    parameter BURST_LEN = 3  // READ/WRITE Burst Length
)
();

//--------------------
// data/address/burst length FIFO
//--------------------
int dfifo[$]; // data fifo
int afifo[$]; // address  fifo
int bfifo[$]; // Burst Length fifo

// Initialize Configuration Parameters
initial begin
    top_hdl.cfg.setup();
end

reg [31:0] read_data;
reg [31:0] ErrCnt;
int k;
reg [31:0] StartAddr;
/////////////////////////////////////////////////////////////////////////
// Test Case
/////////////////////////////////////////////////////////////////////////

initial begin
    

    $display("Waiting for reset");
    top_hdl.wbi.waitForReset();
    $display("Reset finished");
    

   ErrCnt          = 0;
    
  //wait(top_hdl.cfg.sdr_init_done === 1);
  @(posedge top_hdl.cfg.sdr_init_done) $display("SDR Init done");

  $display("-------------------------------------- ");
  $display(" Case-1: Single Write/Read Case        ");
  $display("-------------------------------------- ");
/*
  burst_write(32'h4_0000,8'h4);

  burst_read();
/*
  // Repeat one more time to analysis the
  // SDRAM state change for same col/row address
  $display("-------------------------------------- ");
  $display(" Case-2: Repeat same transfer once again ");
  $display("----------------------------------------");
  burst_write(32'h4_0000,8'h4);
  burst_read();
  burst_write(32'h0040_0000,8'h5);
  burst_read();
  $display("----------------------------------------");
  $display(" Case-3 Create a Page Cross Over        ");
  $display("----------------------------------------");
  burst_write(32'h0000_0FF0,8'h8);
  burst_write(32'h0001_0FF4,8'hF);
  burst_write(32'h0002_0FF8,8'hF);
  burst_write(32'h0003_0FFC,8'hF);
  burst_write(32'h0004_0FE0,8'hF);
  burst_write(32'h0005_0FE4,8'hF);
  burst_write(32'h0006_0FE8,8'hF);
  burst_write(32'h0007_0FEC,8'hF);
  burst_write(32'h0008_0FD0,8'hF);
  burst_write(32'h0009_0FD4,8'hF);
  burst_write(32'h000A_0FD8,8'hF);
  burst_write(32'h000B_0FDC,8'hF);
  burst_write(32'h000C_0FC0,8'hF);
  burst_write(32'h000D_0FC4,8'hF);
  burst_write(32'h000E_0FC8,8'hF);
  burst_write(32'h000F_0FCC,8'hF);
  burst_write(32'h0010_0FB0,8'hF);
  burst_write(32'h0011_0FB4,8'hF);
  burst_write(32'h0012_0FB8,8'hF);
  burst_write(32'h0013_0FBC,8'hF);
  burst_write(32'h0014_0FA0,8'hF);
  burst_write(32'h0015_0FA4,8'hF);
  burst_write(32'h0016_0FA8,8'hF);
  burst_write(32'h0017_0FAC,8'hF);
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();

  $display("----------------------------------------");
  $display(" Case:4 4 Write & 4 Read                ");
  $display("----------------------------------------");
  burst_write(32'h4_0000,8'h4);
  burst_write(32'h5_0000,8'h5);
  burst_write(32'h6_0000,8'h6);
  burst_write(32'h7_0000,8'h7);
  burst_read();
  burst_read();
  burst_read();
  burst_read();

  $display("---------------------------------------");
  $display(" Case:5 24 Write & 24 Read With Different Bank and Row ");
  $display("---------------------------------------");
  //----------------------------------------
  // Address Decodeing:
  //  with cfg_col bit configured as: 00
  //    <12 Bit Row> <2 Bit Bank> <8 Bit Column> <2'b00>
  //
  burst_write({12'h000,2'b00,8'h00,2'b00},8'h4);   // Row: 0 Bank : 0
  burst_write({12'h000,2'b01,8'h00,2'b00},8'h5);   // Row: 0 Bank : 1
  burst_write({12'h000,2'b10,8'h00,2'b00},8'h6);   // Row: 0 Bank : 2
  burst_write({12'h000,2'b11,8'h00,2'b00},8'h7);   // Row: 0 Bank : 3
  burst_write({12'h001,2'b00,8'h00,2'b00},8'h4);   // Row: 1 Bank : 0
  burst_write({12'h001,2'b01,8'h00,2'b00},8'h5);   // Row: 1 Bank : 1
  burst_write({12'h001,2'b10,8'h00,2'b00},8'h6);   // Row: 1 Bank : 2
  burst_write({12'h001,2'b11,8'h00,2'b00},8'h7);   // Row: 1 Bank : 3
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();

  burst_write({12'h002,2'b00,8'h00,2'b00},8'h4);   // Row: 2 Bank : 0
  burst_write({12'h002,2'b01,8'h00,2'b00},8'h5);   // Row: 2 Bank : 1
  burst_write({12'h002,2'b10,8'h00,2'b00},8'h6);   // Row: 2 Bank : 2
  burst_write({12'h002,2'b11,8'h00,2'b00},8'h7);   // Row: 2 Bank : 3
  burst_write({12'h003,2'b00,8'h00,2'b00},8'h4);   // Row: 3 Bank : 0
  burst_write({12'h003,2'b01,8'h00,2'b00},8'h5);   // Row: 3 Bank : 1
  burst_write({12'h003,2'b10,8'h00,2'b00},8'h6);   // Row: 3 Bank : 2
  burst_write({12'h003,2'b11,8'h00,2'b00},8'h7);   // Row: 3 Bank : 3

  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();

  burst_write({12'h002,2'b00,8'h00,2'b00},8'h4);   // Row: 2 Bank : 0
  burst_write({12'h002,2'b01,8'h01,2'b00},8'h5);   // Row: 2 Bank : 1
  burst_write({12'h002,2'b10,8'h02,2'b00},8'h6);   // Row: 2 Bank : 2
  burst_write({12'h002,2'b11,8'h03,2'b00},8'h7);   // Row: 2 Bank : 3
  burst_write({12'h003,2'b00,8'h04,2'b00},8'h4);   // Row: 3 Bank : 0
  burst_write({12'h003,2'b01,8'h05,2'b00},8'h5);   // Row: 3 Bank : 1
  burst_write({12'h003,2'b10,8'h06,2'b00},8'h6);   // Row: 3 Bank : 2
  burst_write({12'h003,2'b11,8'h07,2'b00},8'h7);   // Row: 3 Bank : 3

  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  burst_read();
  $display("---------------------------------------------------");
  $display(" Case: 6 Random 2 write and 2 read random");
  $display("---------------------------------------------------");
  for(k=0; k < 20; k++) begin
     StartAddr = $random & 32'h003FFFFF;
     burst_write(StartAddr,($random & 8'h0f)+1);
     StartAddr = $random & 32'h003FFFFF;
     burst_write(StartAddr,($random & 8'h0f)+1);
     burst_read();
     burst_read();
  end
  
  */


        $display("###############################");
    if(ErrCnt == 0)
        $display("STATUS: SDRAM Write/Read TEST PASSED");
    else
        $display("ERROR:  SDRAM Write/Read TEST FAILED");
        $display("###############################");
    $finish;
end


task burst_write;
   input [31:0] Address;
   input [7:0]  bl;
   int i;

   automatic logic [31:0] data = $random & 32'hFFFFFFFF;

   afifo.push_back(Address);
   bfifo.push_back(bl);

   for(i=0; i < bl; i++) begin

      dfifo.push_back(data);
      $display("tb_top:  Status: Burst-No: %d  Write Address: %x  WriteData: %x ",i,Address,data);
      top_hdl.wbi.write(Address[31:2]+i, bl, data);
   end

endtask

task burst_read();
   automatic logic [31:0] address = afifo.pop_front();
   automatic logic  [7:0] bl      = bfifo.pop_front();
   logic [31:0] exp_data, data;
   int j;

   for(j=0; j < bl; j++) begin
      $display("tb_top:  Read Address: %x, Burst Size: %d",address,bl);
      top_hdl.wbi.read(address[31:2]+j, bl, data);
      exp_data = dfifo.pop_front();
      if (data !== exp_data) begin
          $display("tb_top:  READ ERROR: Burst-No: %d Addr: %x Rxp: %x Exd: %x",j,address,data,exp_data);
          ErrCnt = ErrCnt+1;
      end else begin
          $display("tb_top:  READ STATUS: Burst-No: %d Addr: %x Rxd: %x",j,address,data);
      end
   end

endtask


endmodule
