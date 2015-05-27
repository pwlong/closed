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

module top_hvl #()();

// class for storing and manipulating test cases
// two ways to set the address
//      directly set row/bank/column when calling 'new()'
//      call 'new()' with 0s for row/bank/column then call 'setAddress(<32bit address>)'
// data is randomized whenever 'new()' is called
class TestCase;
    logic         [31:0] address;
    logic [255:0] [31:0] data;
    logic          [7:0] bl; // burst length
    logic         [19:0] row;
    logic          [1:0] bank;
    logic          [7:0] column;
    
    function new(logic [19:0] row, logic [1:0] bank, logic [7:0] column, logic [7:0] bl);
        this.row        = row;
        this.bank       = bank;
        this.column     = column;
        this.bl         = bl;
        this.newData();
        this.address    = {row,bank,column,2'b0};   // forces alignment to 4'h0, 4'h4, 4'h8, 4'hC
    endfunction
    
    function void setAddress(logic [31:0] address);
        this.address = address & 32'h00FF_FFFC;     // forces alignment to 4'h0, 4'h4, 4'h8, 4'hC
        this.row = address[31:12];  // pull the row/bank/column out
        this.bank = address[11:10];
        this.column = address[9:2];
    endfunction
    
    function logic [31:0] getAddress();
        return this.address;
    endfunction
    
    function logic [7:0] [31:0] getData();
        return this.data;
    endfunction
    
    function void newData();
        foreach (data[k]) begin
            if (k < this.bl)
                this.data[k]       = $random & 32'hFFFFFFFF;
        end
    endfunction
    
    function void setBL(logic [7:0] bl); // burst length
        this.bl = bl;
    endfunction
    
    function logic [7:0] getBL(); // burst length
        return this.bl;
    endfunction
    
    function void print();
        //string data, d;
        //for (int i = 7; i >= 0; i--) begin          // pretty print prints as integers... this formats to hex for smaller prints
        //    $sformat(d, "%8h", this.data[i]);
        //    data = {data, ", ", d};
        //end
        $display("Transaction - address=%h, row=%5h, bank=%1d, column=%2h, bl=%3h", this.address, this.row, this.bank, this.column, this.bl);
        //$display("Transaction - data = %s", data);
    endfunction

endclass

TestCase tcfifo[$]; // queue to hold test cases currently executing

// variables to use throughout testbench 
TestCase t;
logic [19:0] row;
logic  [1:0] bank;
logic  [7:0] column;
logic [31:0] address;
logic  [7:0] bl;
longint ErrCnt;
int i, j, k, writes;


// set up a dummy interface for assertion checking
logic hvl_sdram_clk     = 0,
      hvl_sdram_clk_d   = 0,
      hvl_RESETN        = 1, // reset is active low
      hvl_sdr_init_done = 0; // when sdr_init_done is asserted, the FSM can move

sdr_bus #(.SDR_DW(top_hdl.SDR_DW),
          .SDR_BW(top_hdl.SDR_BW),
          .BURST_LENGTH(top_hdl.BURST_LEN),
          .TRAS(top_hdl.TRAS_D),
          .TCAS(top_hdl.TCAS),
          .TRCD(top_hdl.TRCD_D),
          .TRP(top_hdl.TRP_D),
          .TWR(top_hdl.TWR)
) sdrif_test (.sdram_clk(hvl_sdram_clk),
             .sdram_clk_d(hvl_sdram_clk_d),
             .sdram_resetn(hvl_RESETN),
             .sdr_init_done(hvl_sdr_init_done)
);

import sdr_pack::*;
int immediateAssertFailsExpected = 0;
int trasAssertFailsExpected [0:3] = '{0,0,0,0};
int trcdAssertFailsExpected [0:3] = '{0,0,0,0};
int twrAssertFailsExpected  [0:3] = '{0,0,0,0};
int trpAssertFailsExpected  [0:3] = '{0,0,0,0};

// variable to drive the dummy sdrif
cmd_t sdrif_cmd = cmd_t'(0);
assign {sdrif_test.sdr_cs_n, sdrif_test.sdr_ras_n, sdrif_test.sdr_cas_n, sdrif_test.sdr_we_n} = sdrif_cmd;

// generate dummy interface clocks
always #(top_hdl.P_SDR/2) hvl_sdram_clk = ~hvl_sdram_clk;

// list of valid commands for each state
cmd_t validCommands[bankState_t][$];
cmd_t commands [$];
initial begin
    commands.push_back(CMD_NOP);
    commands.push_back(CMD_ACTIVE);
    commands.push_back(CMD_AUTO_REFRESH);
    commands.push_back(CMD_LOAD_MODE_REGISTER);
    commands.push_back(CMD_PRECHARGE);
    validCommands[IDLE] = commands;         // 5 valid commands, 3 invalid
    commands = {};
    
    commands.push_back(CMD_NOP);
    validCommands[REFRESHING] = commands;   // 1 valid command,  7 invalid
    validCommands[ACTIVATING] = commands;   // 1 valid command,  7 invalid
    validCommands[RD_W_PC] = commands;      // 1 valid command,  7 invalid
    validCommands[WR_W_PC] = commands;      // 1 valid command,  7 invalid
    validCommands[PRECHARGING] = commands;  // 1 valid command,  7 invalid
    commands = {};
    
    commands.push_back(CMD_NOP);
    commands.push_back(CMD_READ);
    commands.push_back(CMD_WRITE);
    commands.push_back(CMD_PRECHARGE);
    validCommands[ACTIVE] = commands;       // 4 valid commands, 4 invalid
    
    commands.push_back(CMD_BURST_TERMINATE);
    validCommands[RD] = commands;           // 5 valid commands, 3 invalid
    validCommands[WR] = commands;           // 5 valid commands, 3 invalid
    commands = {};
    
    validCommands[INITIALIZING] = commands; // 0 valid commands, 8 invalid
    
    // (3+7+7+7+7+7+4+3+3+8)*4 = 224 invalid commands
    // (5+1+1+1+1+1+4+5+5+0)*4 =  96   valid commands
    // total of 320 commands across all four banks
    
    $display("validCommands = %p", validCommands);
end











// Initialize Configuration Parameters and HVL<->HDL interface 
initial begin
    top_hdl.cfg.setup();
    wbsetup();
end

// initialize the sdrif for breaking assertions
initial begin
    sdrif_reset();
end

/////////////////////////////////////////////////////////////////////////
// Test Case
/////////////////////////////////////////////////////////////////////////
initial begin
    //top_hdl.sdram_bus.VERBOSE = 0; // turn off prints from the bus used in top_hdl
    $display("Waiting for reset");
    waitForReset();
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
    burst_write(t);             // 5th write
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
    burst_write(t);             // 10th write
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
    burst_write(t);             // 15th write
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
    burst_write(t);             // 20th write
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
    burst_write(t);             // 24th and final write
    
    readAllQueue(); // read out the previous writes
    
    
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
    readAllQueue(); // read out the previous writes
  

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
    
    readAllQueue(); // read out the previous writes
    
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
    
    readAllQueue(); // read out the previous writes
  
    $display("---------------------------------------------------");
    $display(" Case-6: 20 loops of random numbers of random address/data write of random burst lengths and the same number of reads");
    $display("---------------------------------------------------");
    for(k = 0; k < 50; k++) begin
        writes = $urandom_range(0, 20);
        for (i = 0; i < writes; i++) begin
            t = new(0,0,0,($random & 8'h0f)+1);
            t.setAddress($random & 32'h003FFFFF);
            burst_write(t);
        end
        readAllQueue(); // read out the previous writes
    end
  
  
    $display("---------------------------------------------------");
    $display(" Case-7: Same as before but randomizing the number of reads done between writes");
    $display("---------------------------------------------------");
    for(k = 0; k < $urandom_range(20, 50); k++) begin
        writes = $urandom_range(0, 20);
        for (i = 0; i < writes; i++) begin
            j = ($random & 8'h0f)+1;
            $display("J = %d", j);
            t = new(0,0,0,($random & 8'h0f)+1);
            t.setAddress($random & 32'h003FFFFF);
            burst_write(t);
        end
        $display(" case 7 - writes: %2d finished", writes);
        writes = $urandom_range(0, writes); // read a random number of the previous writes
        for (i = 0; i < writes; i++) begin
            burst_read();
        end
        $display(" case 7 - reads: %2d finished, %3d test cases left in queue", writes, tcfifo.size());
    end
    
    $display(" case 7 - emptying queue");
    readAllQueue(); // there may be a significant number of test cases left in the queue, make sure to read them all before proceeding
  
  

    $display("###############################");
    if (ErrCnt == 0)
        $display("STATUS: SDRAM Write/Read TEST PASSED");
    else
        $display("ERROR:  SDRAM Write/Read TEST FAILED");
    $display("###############################");
    
    $display("SDRAM state counts for each bank:");
    for (int b = 0; b < 4; b++) begin
        $display("====== Bank %1d ======", b);
        $display("%d idle count", top_hdl.sdram_bus.idleCount[b]);
        $display("%d activating count", top_hdl.sdram_bus.activatingCount[b]);
        $display("%d active count", top_hdl.sdram_bus.activeCount[b]);
        $display("%d refreshing count", top_hdl.sdram_bus.refreshingCount[b]);
        $display("%d wr count", top_hdl.sdram_bus.wrCount[b]);
        $display("%d wr_w_pc count", top_hdl.sdram_bus.wrwpcCount[b]);
        $display("%d rd count", top_hdl.sdram_bus.rdCount[b]);
        $display("%d rd_w_pc count", top_hdl.sdram_bus.rdwpcCount[b]);
        $display("%d precharging count", top_hdl.sdram_bus.prechargingCount[b]);
    end
    $display("###############################");
    if (top_hdl.sdram_bus.assertFailCount == 0)
        $display("ASSERTIONS: ALL PASSED");
    else
        $display("ASSERTIONS: %d FAILED", top_hdl.sdram_bus.assertFailCount);
    $display("###############################");
    
    top_hdl.sdram_bus.VERBOSE = 0; // turn off prints from the bus used in top_hdl
    
    // ---------------------------------------------
    // Begin Assertion Testing on dummy SDRAM interface
    // ---------------------------------------------
    
    $display("\n\n\n\n###############################");
    $display("Testing dummy interface to break assertions");
    $display("###############################");
    sdrif_test.VERBOSE = 0;
    sdrif_test.sdr_fsm_en = 0; // shut off the FSM, not needed for immediate assertion testing
    sdrif_immediateAssertionTest();
    $display("###############################");
    if (sdrif_test.assertFailCount == immediateAssertFailsExpected)
        $display("IMMEDIATE ASSERTIONS: %d FAILED of an expected %d, success!", sdrif_test.assertFailCount, immediateAssertFailsExpected);
    else
        $display("IMMEDIATE ASSERTIONS: %d FAILED of an expected %d, failure!", sdrif_test.assertFailCount, immediateAssertFailsExpected);
    $display("###############################");
    
    
    
    $display("\n\n\n\n###############################");
    $display("TESTING CONCURRENT ASSERTIONS");
    // reset the interface
    sdrif_test.sdr_fsm_en = 1;
    hvl_RESETN = 0;
    repeat (5) @(posedge hvl_sdram_clk);
    hvl_RESETN = 1;
    repeat (5) @(posedge hvl_sdram_clk);
    sdrif_test.sdr_fsm_en = 0; // shut off the FSM, not needed for concurrent assertion testing
    sdrif_concurrentAssertionTest();
    
    $display("###############################");
    for (int b = 0; b < 4; b++) begin
        $display("Bank %1d CONCURRENT ASSERTIONS:", b);
        $display("       # failed, # expected");
        $display("TRAS - %d, %d - %s", sdrif_test.trasViolationCount[b], trasAssertFailsExpected[b], (sdrif_test.trasViolationCount[b] === trasAssertFailsExpected[b]) ? "success!" : "failure!");
        $display("TRCD - %d, %d - %s", sdrif_test.trcdViolationCount[b], trcdAssertFailsExpected[b], (sdrif_test.trcdViolationCount[b] === trcdAssertFailsExpected[b]) ? "success!" : "failure!");
        $display("TRP  - %d, %d - %s", sdrif_test.trpViolationCount[b],   trpAssertFailsExpected[b], (sdrif_test.trpViolationCount[b]  ===  trpAssertFailsExpected[b]) ? "success!" : "failure!");
        $display("TWR  - %d, %d - %s", sdrif_test.twrViolationCount[b],   twrAssertFailsExpected[b], (sdrif_test.twrViolationCount[b]  ===  twrAssertFailsExpected[b]) ? "success!" : "failure!");
    end
    $display("###############################");
    
    
    
    $finish;
end





















// issue a number of writes
// input: TestCase - class that holds address, data, and burst length
//                   burst length is used to determine the number of writes to issue
task burst_write;
    input TestCase tc;
    int i;
    logic [31:0] d;
    
    tcfifo.push_back(tc);
    tc.print();
    
    for(i = 0; i < tc.getBL(); i++) begin
        d = tc.getData()[i];
        $display("top_hvl:  Status: Burst-No: %d  Write Address: %x  WriteData: %x ", i, tc.getAddress()[31:2]+i, d);
        top_hdl.wbi.write(tc.getAddress()[31:2]+i, tc.getBL(), d);
    end

endtask

// issue a number of reads
// input: none - instead, pop the oldest test case off the queue and use that
//        just like a write, the test case stores the address, data, and burst length
//        again, burst length used to determine number of reads to issue
task burst_read();
    automatic TestCase tc = tcfifo.pop_back();
    logic [31:0] data, d;
    int i;
    
    $display("top_hvl:  Read Address: %x, Burst Size: %d", tc.getAddress(), tc.getBL());
    for(i = 0; i < tc.getBL(); i++) begin
        top_hdl.wbi.read(tc.getAddress()[31:2]+i, tc.getBL(), data);
        d = tc.getData()[i];
        if (data !== d) begin
            $display("top_hvl:  READ ERROR: Burst-No: %d Addr: %x Rxp: %x Exd: %x", i, tc.getAddress()[31:2]+i, data, d);
            ErrCnt = ErrCnt+1;
        end else begin
            $display("top_hvl:  READ STATUS: Burst-No: %d Addr: %x Rxd: %x", i, tc.getAddress()[31:2]+i, data);
        end
    end
endtask

// empty the queue of test cases by reading them out one by one
task readAllQueue;
    #100;
    while (tcfifo.size > 0) begin
        #100;
        burst_read();
    end
endtask

// wait for reset to complete
task waitForReset;
    @(negedge top_hdl.wbi.wb_rst_i);
endtask

// initialize the wishbone interface with what is essentially a NOP
task wbsetup;
    top_hdl.wbi.wb_addr_i      = 0;
    top_hdl.wbi.wb_dat_i       = 0;
    top_hdl.wbi.wb_sel_i       = 4'h0;
    top_hdl.wbi.wb_we_i        = 0;
    top_hdl.wbi.wb_stb_i       = 0;
    top_hdl.wbi.wb_cyc_i       = 0;
endtask







// tasks for testing the interface
task sdrif_reset;
    sdrif_off();
    #(100);
    sdrif_on();
    #(100);
endtask

task sdrif_off;
    hvl_RESETN <= 0;
    hvl_sdr_init_done <= 0;
endtask

task sdrif_on;
    hvl_RESETN <= 1;
    hvl_sdr_init_done <= 1;
endtask

// loop through the possible states and break the assertions associated with that state 
task sdrif_immediateAssertionTest;
    automatic cmd_t command = cmd_t'(0);
    automatic bankState_t state [3:0];
    
    // to begin, force all banks into IDLE state
    sdrif_reset();
    for (int i = 0; i < 4; i++) begin
        state[i] = IDLE;
    end
    
    // loop through banks
    for (int i = 0; i < 4; i++) begin
        while (state[i] <= PRECHARGING) begin
            sdrif_test.sdr_ba = i;  // assert bank enable for that bank
            for (int j = 0; j < 8; j++) begin
                sdrif_setcmd(command, state[i], i);
                command = cmd_t'(command + 1);
            end
            state[i] = bankState_t'(state[i]+1);
            command = cmd_t'(0);
        end
    end
endtask

task sdrif_setcmd(cmd_t cmd, bankState_t bs, int bank);
    automatic logic valid = 0;
    automatic logic [3:0] vc [$] = validCommands[bs];
    $display("top_hvl: Testing %s for state %s", cmd.name, bs.name);
    
    @(posedge hvl_sdram_clk);
    sdrif_test.bankState[bank] = bs;
    sdrif_cmd = cmd;
    
    @(negedge hvl_sdram_clk);
    foreach (vc[bank]) begin
        if (cmd === vc[bank]) begin
            valid = 1;
        end
    end
    if (~valid) begin
        immediateAssertFailsExpected++;
    end
endtask






task sdrif_concurrentAssertionTest;
    automatic bankState_t state [3:0];
    
    for (int b = 0; b < 4; b++) begin
        sdrif_test.sdr_ba = b;      // assert bank enable for that bank
        sdrif_cmd = CMD_NOP; // ensure cmd doing nothing
        
        // tras, trcd, and twr tests don't need any particular state, can set to idle
        sdrif_test.bankState[b] = IDLE;
        if (top_hdl.TRAS_D > 1)
            sdrif_tras(b);
        else
            $display("TRAS too small to test, can't violate");
            
        if (top_hdl.TRCD_D > 1)
            sdrif_trcd(b);
        else
            $display("TRAS too small to test, can't violate");
            
        if (top_hdl.TWR > 1)
            sdrif_twr(b);
        else
            $display("TWR too small to test, can't violate");
            
        if (top_hdl.TRP_D > 1)
            sdrif_trp(b);
        else
            $display("TRP too small to test, can't violate");
        
    end

endtask

task sdrif_tras(integer bank);
    // to break assertion, send active, then less than TRAS clocks later, send precharge
    static integer minClocks = top_hdl.TRAS_D;
    $display("TRAS test - TRAS = %2d", minClocks);
    
    for (int clks = 1; clks <= minClocks+1; clks++) begin
        @(posedge hvl_sdram_clk);
        sdrif_cmd = CMD_ACTIVE;
        @(posedge hvl_sdram_clk);
        
        if (clks > 1) begin
            sdrif_cmd = CMD_NOP;
            repeat (clks-1) @(posedge hvl_sdram_clk);
        end
        
        sdrif_cmd = CMD_PRECHARGE;
        @(posedge hvl_sdram_clk);
        sdrif_cmd = CMD_NOP;
        @(posedge hvl_sdram_clk);
        
        if (clks < minClocks)
            trasAssertFailsExpected[bank]++;
    end
endtask

task sdrif_trcd(integer bank);
    // to break assertion, send active, then less than TRCD clocks later, send read or write
    static integer minClocks = top_hdl.TRCD_D;
    $display("TRCD test - TRCD = %2d", minClocks);
    
    for (int clks = 1; clks <= minClocks; clks++) begin
        @(posedge hvl_sdram_clk);
        sdrif_cmd = CMD_ACTIVE;
        @(posedge hvl_sdram_clk);
        
        if (clks > 1) begin
            sdrif_cmd = CMD_NOP;
            repeat (clks-1) @(posedge hvl_sdram_clk);
        end
        
        sdrif_cmd = CMD_WRITE;
        @(posedge hvl_sdram_clk);
        sdrif_cmd = CMD_NOP;
        @(posedge hvl_sdram_clk);
        
        if (clks < minClocks)
            trcdAssertFailsExpected[bank]++;
    end
    
    for (int clks = 1; clks <= minClocks; clks++) begin
        @(posedge hvl_sdram_clk);
        sdrif_cmd = CMD_ACTIVE;
        @(posedge hvl_sdram_clk);
        
        if (clks > 1) begin
            sdrif_cmd = CMD_NOP;
            repeat (clks-1) @(posedge hvl_sdram_clk);
        end
        
        sdrif_cmd = CMD_READ;
        @(posedge hvl_sdram_clk);
        sdrif_cmd = CMD_NOP;
        @(posedge hvl_sdram_clk);
        
        if (clks < minClocks)
            trcdAssertFailsExpected[bank]++;
    end
endtask

task sdrif_twr(integer bank);
    // to break assertion, send write, then less than TWR clocks later, send precharge
    static integer minClocks = top_hdl.TWR;
    $display("TWR test - TWR = %2d", minClocks);
    
    for (int clks = 1; clks <= minClocks; clks++) begin
        @(posedge hvl_sdram_clk);
        sdrif_cmd = CMD_WRITE;
        @(posedge hvl_sdram_clk);
        
        if (clks > 1) begin
            sdrif_cmd = CMD_NOP;
            repeat (clks-1) @(posedge hvl_sdram_clk);
        end
        
        sdrif_cmd = CMD_PRECHARGE;
        @(posedge hvl_sdram_clk);
        sdrif_cmd = CMD_NOP;
        @(posedge hvl_sdram_clk);
        
        if (clks < minClocks)
            twrAssertFailsExpected[bank]++;
    end
endtask

task sdrif_trp(integer bank);
    // to break assertion, send precharge when not in IDLE, then less than TRP clocks later, send any command other than a NOP
    static integer minClocks = top_hdl.TRP_D;
    $display("TRP test - TRP = %2d", minClocks);
    
    // first, force bank to something other than IDLE
    sdrif_test.bankState[bank] = WR;
    for (int clks = 1; clks <= minClocks; clks++) begin
        @(posedge hvl_sdram_clk);
        sdrif_cmd = CMD_PRECHARGE;
        @(posedge hvl_sdram_clk);
        
        if (clks > 1) begin
            sdrif_cmd = CMD_NOP;
            repeat (clks-1) @(posedge hvl_sdram_clk);
        end
        
        sdrif_cmd = CMD_WRITE;
        @(posedge hvl_sdram_clk);
        sdrif_cmd = CMD_NOP;
        repeat (top_hdl.TWR) @(posedge hvl_sdram_clk); // need to repeat the NOP for TWR cycles to not accidentally fail TWR
        
        if (clks < minClocks)
            trpAssertFailsExpected[bank]++;
    end
    sdrif_test.bankState[bank] = IDLE; // reset bank state to IDLE for next test
endtask

endmodule



