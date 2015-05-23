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

// class for storing and manipulating test cases
class TestCase;
    logic [31:0] address;
    logic  [7:0] [31:0] data;
    logic  [7:0] bl; // burst length
    logic [19:0] row;
    logic  [1:0] bank;
    logic  [7:0] column;
    
    function new(logic [19:0] row, logic [1:0] bank, logic [7:0] column, logic [7:0] bl);
        int i = 0;
        this.row        = row;
        this.bank       = bank;
        this.column     = column;
        this.bl         = bl;
        for (i = 0; i < 8; i++) begin
            if (i < this.bl)
                this.data[i]       = $random & 32'hFFFFFFFF;
        end
        this.address    = {row,bank,column,2'b0};
    endfunction
    
    function void setAddress(logic [31:0] address);
        this.address = address & 32'h00FF_FFFC;
        this.row = address[31:12];
        this.bank = address[11:10];
        this.column = address[9:2];
    endfunction
    
    function logic [31:0] getAddress();
        return this.address;
    endfunction
    
    function logic [7:0] [31:0] getData();
        return this.data;
    endfunction
    
    function void setBL(logic [7:0] bl);
        this.bl = bl;
    endfunction
    
    function logic [7:0] getBL();
        return this.bl;
    endfunction
    
    function void print();
        string data, d;
        int i;
        for (i = 7; i >= 0; i--) begin          // pretty print prints as integers... this formats to hex for smaller prints
            $sformat(d, "%8h", this.data[i]);
            data = {data, ", ", d};
        end
        $display("Transaction - address=%h, row=%5h, bank=%1d, column=%2h, bl=%3h", this.address, this.row, this.bank, this.column, this.bl);
        $display("Transaction - data = %s", data);
    endfunction

endclass








module top_hvl #(
)
();

TestCase tcfifo[$]; // queue to hold test cases currently executing

// variables to use throughout testbench 
TestCase t;
logic [19:0] row;
logic  [1:0] bank;
logic  [7:0] column;
logic [31:0] address;
logic  [7:0] bl;
longint ErrCnt;
int i, k, writes;

// Initialize Configuration Parameters
initial begin
    top_hdl.cfg.setup();
end

/////////////////////////////////////////////////////////////////////////
// Test Case
/////////////////////////////////////////////////////////////////////////
initial begin
    
    $display("Waiting for reset");
    top_hdl.wbi.waitForReset();
    $display("Reset finished");
    

    ErrCnt = 0;
    
    @(posedge top_hdl.cfg.sdr_init_done) $display("SDR Init done");
    
    $display("-------------------------------------- ");
    $display(" Case-1: Single Write/Read Case        ");
    $display("-------------------------------------- ");
    
    t = new(.row(12'h100), .bank(0), .column(0), .bl(8'h4));
    burst_write(t);
    burst_read();
    
    
    // Repeat one more time to analysis the
    // SDRAM state change for same col/row address
    $display("-------------------------------------- ");
    $display(" Case-2: Repeat same transfer once again ");
    $display("----------------------------------------");
    t = new(.row(20'h100), .bank(0), .column(0), .bl(8'h4));
    burst_write(t);
    burst_read();
    t = new(.row(20'h100), .bank(0), .column(0), .bl(8'h4));
    burst_write(t);
    burst_read();
    
    
    $display("----------------------------------------");
    $display(" Case-3: Create a Page Cross Over        ");
    $display("----------------------------------------");
    bl = 8'h8;
    t = new(0,0,0,bl);
    t.setAddress(32'h0000_0FF0);
    burst_write(t);
    // call new in between each write in order to regenerate data
    bl = 8'hF;
    t = new(0,0,0,bl);
    t.setAddress(32'h0001_0FF4);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0002_0FF8);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0003_0FFC);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0004_0FE0);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0005_0FE4);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0006_0FE8);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0007_0FEC);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0008_0FD0);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0009_0FD4);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h000A_0FD8);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h000B_0FDC);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h000C_0FC0);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h000D_0FC4);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h000E_0FC8);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h000F_0FCC);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0010_0FB0);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0011_0FB4);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0012_0FB8);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0013_0FBC);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0014_0FA0);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0015_0FA4);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0016_0FA8);
    burst_write(t);
    t = new(0,0,0,bl);
    t.setAddress(32'h0017_0FAC);
    burst_write(t);
    
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
    $display(" Case-4: 4 Write & 4 Read                ");
    $display("----------------------------------------");
    row = 20'h00010;
    bank = 0;
    column = 0;
    bl = 8'h4;
    
    for (i = 0; i < 4; i++) begin
        if (i > 0)
            row = row + 16;
        t = new(row, bank, column, bl++);
        burst_write(t);
    end
    
    burst_read();
    burst_read();
    burst_read();
    burst_read();
  

    $display("---------------------------------------");
    $display(" Case-5: 24 Write & 24 Read With Different Bank and Row ");
    $display("---------------------------------------");
    // loop through each row, within each row loop through each bank
    // start with burst length of 4, increasing by 1 each time, resetting to 4 every 4th write
    row = 0;
    bank = 0;
    column = 0;
    bl = 4;
    for (i = 0; i < 16; i++) begin
        if (i % 4 == 0 && i > 0) begin
            row++;
            bl = 0;
        end
        t = new(row, bank, column, bl);
        burst_write(t);
        bl++;
        bank++;
    end
    for (i = 0; i < 16; i++) begin
        burst_read();
    end
    
    // same thing but increment column each time
    row = 2;
    bank = 0;
    column = 0;
    bl = 4;
    for (i = 0; i < 8; i++) begin
        if (i % 4 == 0 && i > 0) begin
            row++;
            bl = 0;
        end
        t = new(row, bank, column, bl);
        burst_write(t);
        bl++;
        bank++;
        column++;
    end
    for (i = 0; i < 8; i++) begin
        burst_read();
    end
  
    $display("---------------------------------------------------");
    $display(" Case-6: 20 loops of random numbers of random address/data write of random burst lengths and the same number of reads");
    $display("---------------------------------------------------");
    for(k = 0; k < 20; k++) begin
        writes = $urandom_range(0, 20);
        for (i = 0; i < writes; i++) begin
            t = new(0,0,0,($random & 8'h0f)+1);
            t.setAddress($random & 32'h003FFFFF);
            burst_write(t);
        end
        for (i = 0; i < writes; i++) begin
            burst_read;
        end
    end
  
  
    $display("---------------------------------------------------");
    $display(" Case-7: Same as before but randomizing the number of reads done between writes");
    $display("---------------------------------------------------");
    for(k = 0; k < $urandom_range(0, 20); k++) begin
        writes = $urandom_range(0, 20);
        for (i = 0; i < writes; i++) begin
            t = new(0,0,0,($random & 8'h0f)+1);
            t.setAddress($random & 32'h003FFFFF);
            burst_write(t);
        end
        $display(" case 7 - writes: %2d finished", writes);
        writes = $urandom_range(0, writes);
        for (i = 0; i < writes; i++) begin
            burst_read();
        end
        $display(" case 7 - reads: %2d finished, %3d test cases left in queue", writes, tcfifo.size());
    end
    // empty the queue to prepare for next case
    i = tcfifo.size();
    $display(" case 7 - emptying queue");
    for (k = 0; k < i; k++) begin
        burst_read();
    end
  
  

    $display("###############################");
    if(ErrCnt == 0)
        $display("STATUS: SDRAM Write/Read TEST PASSED");
    else
        $display("ERROR:  SDRAM Write/Read TEST FAILED");
    $display("###############################");
    $finish;
end


task burst_write;
    input TestCase tc;
    int i;
    logic [31:0] d;
    
    tcfifo.push_back(tc);
    tc.print();
    
    for(i = 0; i < tc.getBL(); i++) begin
        d = tc.getData()[i];
        $display("tb_top:  Status: Burst-No: %d  Write Address: %x  WriteData: %x ", i, tc.getAddress()[31:2]+i, d);
        top_hdl.wbi.write(tc.getAddress()[31:2]+i, tc.getBL(), d);
    end

endtask

task burst_read();
    automatic TestCase tc = tcfifo.pop_front();
    logic [31:0] data, d;
    int i;
    
    for(i = 0; i < tc.getBL(); i++) begin
        $display("tb_top:  Read Address: %x, Burst Size: %d", tc.getAddress(), tc.getBL());
        top_hdl.wbi.read(tc.getAddress()[31:2]+i, tc.getBL(), data);
        d = tc.getData()[i];
        if (data !== d) begin
            $display("tb_top:  READ ERROR: Burst-No: %d Addr: %x Rxp: %x Exd: %x", i, tc.getAddress()[31:2]+i, data, d);
            ErrCnt = ErrCnt+1;
        end else begin
            $display("tb_top:  READ STATUS: Burst-No: %d Addr: %x Rxd: %x", i, tc.getAddress()[31:2]+i, data);
        end
    end

endtask


endmodule