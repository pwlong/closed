/**************************************************************************
*
*    File Name:  MT48LC2M32B2.V  
*      Version:  3.0
*         Date:  June 6th, 2002
*        Model:  BUS Functional
*    Simulator:  Model Technology
*
* Dependencies:  None
*
*        Email:  modelsupport@micron.com
*      Company:  Micron Technology, Inc.
*        Model:  MT48LC2M32B2 (512K x 32 x 4 Banks)
*
*  Description:  Micron 64Mb SDRAM Verilog model
*
*   Limitation:  - Doesn't check for 4096 cycle refresh
*
*         Note:  - Set simulator resolution to "ps" accuracy
*                - Set Debug = 0 to disable $display messages
*
*   Disclaimer:  THESE DESIGNS ARE PROVIDED "AS IS" WITH NO WARRANTY 
*                WHATSOEVER AND MICRON SPECIFICALLY DISCLAIMS ANY 
*                IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR
*                A PARTICULAR PURPOSE, OR AGAINST INFRINGEMENT.
*
*                Copyright © 2001 Micron Semiconductor Products, Inc.
*                All rights researved
*
* Rev  Author          Date        Changes
* ---  --------------------------  ---------------------------------------
* 3.0  DJF             5/21/2015   - I fucked shit up so hard, i don't know if that's a face, or a horse hoof. This may or may not synthesize..my hope it that it will, and is not broken.
*
* 2.1  SH              06/06/2002  - Typo in bank multiplex
*      Micron Technology Inc.
*
* 2.0  SH              04/30/2002  - Second release
*      Micron Technology Inc.
*
**************************************************************************/

`timescale 1ns / 1ps

module mt48lc2m32b2 (
    sdr_bus.ram sdram_bus
    //Dq, Addr, Ba, Clk, Cke, Cs_n, Ras_n, Cas_n, We_n, Dqm
);

    parameter addr_bits =      11;
    parameter data_bits =      32;
    parameter col_bits  =       8;
    parameter mem_sizes =  524287;

    wire     [data_bits - 1 : 0] Dq;
    wire     [addr_bits - 1 : 0] Addr;
    wire                 [1 : 0] Ba;
    wire                         Clk;
    wire                         Cke;
    wire                         Cs_n;
    wire                         Ras_n;
    wire                         Cas_n;
    wire                         We_n;
    wire                 [3 : 0] Dqm;
    assign Dq    = sdram_bus.sdr_dq;
    assign Addr  = sdram_bus.sdr_addr;
    assign Ba    = sdram_bus.sdr_ba;
    assign Clk   = sdram_bus.sdram_clk_d;
    assign Cke   = sdram_bus.sdr_cke;
    assign Cs_n  = sdram_bus.sdr_cs_n;
    assign Ras_n = sdram_bus.sdr_ras_n;
    assign Cas_n = sdram_bus.sdr_cas_n;
    assign We_n  = sdram_bus.sdr_we_n;
    assign Dqm   = sdram_bus.sdr_dqm;

    reg       [data_bits - 1 : 0] Bank0 [0 : mem_sizes];
    reg       [data_bits - 1 : 0] Bank1 [0 : mem_sizes];
    reg       [data_bits - 1 : 0] Bank2 [0 : mem_sizes];
    reg       [data_bits - 1 : 0] Bank3 [0 : mem_sizes];

    reg                   [1 : 0] Bank_addr [0 : 3];                // Bank Address Pipeline
    reg        [col_bits - 1 : 0] Col_addr [0 : 3];                 // Column Address Pipeline
    reg                   [3 : 0] Command [0 : 3];                  // Command Operation Pipeline
    reg                   [3 : 0] Dqm_reg0, Dqm_reg1;               // DQM Operation Pipeline
    reg       [addr_bits - 1 : 0] B0_row_addr, B1_row_addr, B2_row_addr, B3_row_addr;

    reg       [addr_bits - 1 : 0] Mode_reg;
    reg       [data_bits - 1 : 0] Dq_reg, Dq_dqm;
    reg        [col_bits - 1 : 0] Col_temp, Burst_counter;

    reg                           Act_b0, Act_b1, Act_b2, Act_b3;   // Bank Activate
    reg                           Pc_b0, Pc_b1, Pc_b2, Pc_b3;       // Bank Precharge

    reg                   [1 : 0] Bank_precharge       [0 : 3];     // Precharge Command
    reg                           A10_precharge        [0 : 3];     // Addr[10] = 1 (All banks)
    reg                           Auto_precharge       [0 : 3];     // RW Auto Precharge (Bank)
    reg                           Read_precharge       [0 : 3];     // R  Auto Precharge
    reg                           Write_precharge      [0 : 3];     //  W Auto Precharge
    reg                           RW_interrupt_read    [0 : 3];     // RW Interrupt Read with Auto Precharge
    reg                           RW_interrupt_write   [0 : 3];     // RW Interrupt Write with Auto Precharge
    reg                   [1 : 0] RW_interrupt_bank;                // RW Interrupt Bank
    integer                       RW_interrupt_counter [0 : 3];     // RW Interrupt Counter
    integer                       Count_precharge      [0 : 3];     // RW Auto Precharge Counter

    reg                           Data_in_enable;
    reg                           Data_out_enable;

    reg                   [1 : 0] Bank, Prev_bank;
    reg       [addr_bits - 1 : 0] Row;
    reg        [col_bits - 1 : 0] Col, Col_brst;

    // Internal system clock
    reg                           CkeZ, Sys_clk;

    // Commands Decode
    wire      Active_enable    = ~Cs_n & ~Ras_n &  Cas_n &  We_n;
    wire      Aref_enable      = ~Cs_n & ~Ras_n & ~Cas_n &  We_n;
    wire      Burst_term       = ~Cs_n &  Ras_n &  Cas_n & ~We_n;
    wire      Mode_reg_enable  = ~Cs_n & ~Ras_n & ~Cas_n & ~We_n;
    wire      Prech_enable     = ~Cs_n & ~Ras_n &  Cas_n & ~We_n;
    wire      Read_enable      = ~Cs_n &  Ras_n & ~Cas_n &  We_n;
    wire      Write_enable     = ~Cs_n &  Ras_n & ~Cas_n & ~We_n;

    // Burst Length Decode
    wire      Burst_length_1   = ~Mode_reg[2] & ~Mode_reg[1] & ~Mode_reg[0];
    wire      Burst_length_2   = ~Mode_reg[2] & ~Mode_reg[1] &  Mode_reg[0];
    wire      Burst_length_4   = ~Mode_reg[2] &  Mode_reg[1] & ~Mode_reg[0];
    wire      Burst_length_8   = ~Mode_reg[2] &  Mode_reg[1] &  Mode_reg[0];
    wire      Burst_length_f   =  Mode_reg[2] &  Mode_reg[1] &  Mode_reg[0];

    // CAS Latency Decode
    wire      Cas_latency_1    = ~Mode_reg[6] & ~Mode_reg[5] &  Mode_reg[4];
    wire      Cas_latency_2    = ~Mode_reg[6] &  Mode_reg[5] & ~Mode_reg[4];
    wire      Cas_latency_3    = ~Mode_reg[6] &  Mode_reg[5] &  Mode_reg[4];

    // Write Burst Mode
    wire      Write_burst_mode = Mode_reg[9];

    wire      Debug            = 1'b1;                          // Debug messages : 1 = On
    wire      Dq_chk           = Sys_clk & Data_in_enable;      // Check setup/hold time for DQ
    
    assign    sdram_bus.sdr_dq = Dq_reg;                        // DQ buffer

    // Commands Operation
    `define   ACT       0
    `define   NOP       1
    `define   READ      2
    `define   WRITE     3
    `define   PRECH     4
    `define   A_REF     5
    `define   BST       6
    `define   LMR       7

    // Timing Parameters for -6 CL3
    parameter tAC  =   5.5;
    parameter tHZ  =   5.5;
    parameter tOH  =   2.5;
    parameter tMRD =   2.0;     // 2 Clk Cycles
    parameter tRAS =  42.0;
    parameter tRC  =  60.0;
    parameter tRCD =  18.0;
    parameter tRFC =  60.0;
    parameter tRP  =  18.0;
    parameter tRRD =  12.0;
    parameter tWRa =   6.0;     // A2 Version - Auto precharge mode (1 Clk + 7 ns)
    parameter tWRm =  12.0;     // A2 Version - Manual precharge mode (14 ns)


    initial begin
        Dq_reg = {data_bits{1'bz}};
        Data_in_enable = 0; Data_out_enable = 0;
        Act_b0 = 1; Act_b1 = 1; Act_b2 = 1; Act_b3 = 1;
        Pc_b0 = 0; Pc_b1 = 0; Pc_b2 = 0; Pc_b3 = 0;

        RW_interrupt_read[0] = 0; RW_interrupt_read[1] = 0; RW_interrupt_read[2] = 0; RW_interrupt_read[3] = 0;
        RW_interrupt_write[0] = 0; RW_interrupt_write[1] = 0; RW_interrupt_write[2] = 0; RW_interrupt_write[3] = 0;

    end

    // System clock generator
    always begin
        @ (posedge Clk) begin
            Sys_clk = CkeZ;
            CkeZ = Cke;
        end
        @ (negedge Clk) begin
            Sys_clk = 1'b0;
        end
    end

    always @ (posedge Sys_clk) begin
        // Internal Commamd Pipelined
        Command[0] = Command[1];
        Command[1] = Command[2];
        Command[2] = Command[3];
        Command[3] = `NOP;

        Col_addr[0] = Col_addr[1];
        Col_addr[1] = Col_addr[2];
        Col_addr[2] = Col_addr[3];
        Col_addr[3] = {col_bits{1'b0}};

        Bank_addr[0] = Bank_addr[1];
        Bank_addr[1] = Bank_addr[2];
        Bank_addr[2] = Bank_addr[3];
        Bank_addr[3] = 2'b0;

        Bank_precharge[0] = Bank_precharge[1];
        Bank_precharge[1] = Bank_precharge[2];
        Bank_precharge[2] = Bank_precharge[3];
        Bank_precharge[3] = 2'b0;

        A10_precharge[0] = A10_precharge[1];
        A10_precharge[1] = A10_precharge[2];
        A10_precharge[2] = A10_precharge[3];
        A10_precharge[3] = 1'b0;

        // Dqm pipeline for Read
        Dqm_reg0 = Dqm_reg1;
        Dqm_reg1 = Dqm;

        // Read or Write with Auto Precharge Counter
        if (Auto_precharge[0] === 1'b1) begin
            Count_precharge[0] = Count_precharge[0] + 1;
        end
        if (Auto_precharge[1] === 1'b1) begin
            Count_precharge[1] = Count_precharge[1] + 1;
        end
        if (Auto_precharge[2] === 1'b1) begin
            Count_precharge[2] = Count_precharge[2] + 1;
        end
        if (Auto_precharge[3] === 1'b1) begin
            Count_precharge[3] = Count_precharge[3] + 1;
        end

        // Read or Write Interrupt Counter
        if (RW_interrupt_write[0] === 1'b1) begin
            RW_interrupt_counter[0] = RW_interrupt_counter[0] + 1;
        end
        if (RW_interrupt_write[1] === 1'b1) begin
            RW_interrupt_counter[1] = RW_interrupt_counter[1] + 1;
        end
        if (RW_interrupt_write[2] === 1'b1) begin
            RW_interrupt_counter[2] = RW_interrupt_counter[2] + 1;
        end
        if (RW_interrupt_write[3] === 1'b1) begin
            RW_interrupt_counter[3] = RW_interrupt_counter[3] + 1;
        end       
        
        // Load Mode Register
        if (Mode_reg_enable === 1'b1) begin
            // Register Mode
            Mode_reg = Addr;
        end
        
        // Active Block (Latch Bank Address and Row Address)
        if (Active_enable === 1'b1) begin    
            // Activate Bank 0
            if (Ba === 2'b00 && Pc_b0 === 1'b1) begin        
                // Record variables
                Act_b0 = 1'b1;
                Pc_b0 = 1'b0;
                B0_row_addr = Addr [addr_bits - 1 : 0];
            end

            if (Ba == 2'b01 && Pc_b1 == 1'b1) begin
                // Record variables
                Act_b1 = 1'b1;
                Pc_b1 = 1'b0;
                B1_row_addr = Addr [addr_bits - 1 : 0];
            end

            if (Ba == 2'b10 && Pc_b2 == 1'b1) begin
                // Record variables
                Act_b2 = 1'b1;
                Pc_b2 = 1'b0;
                B2_row_addr = Addr [addr_bits - 1 : 0];
            end

            if (Ba == 2'b11 && Pc_b3 == 1'b1) begin      
                // Record variables
                Act_b3 = 1'b1;
                Pc_b3 = 1'b0;
                B3_row_addr = Addr [addr_bits - 1 : 0]; 
            end
            // Record variables for checking violation 
            Prev_bank = Ba;
        end
        
        // Precharge Block
        if (Prech_enable == 1'b1) begin
            // Precharge Bank 0
            if ((Addr[10] === 1'b1 || (Addr[10] === 1'b0 && Ba === 2'b00)) && Act_b0 === 1'b1) begin
                Act_b0 = 1'b0;
                Pc_b0 = 1'b1;
            end

            // Precharge Bank 1
            if ((Addr[10] === 1'b1 || (Addr[10] === 1'b0 && Ba === 2'b01)) && Act_b1 === 1'b1) begin
                Act_b1 = 1'b0;
                Pc_b1 = 1'b1;             
            end

            // Precharge Bank 2
            if ((Addr[10] === 1'b1 || (Addr[10] === 1'b0 && Ba === 2'b10)) && Act_b2 === 1'b1) begin
                Act_b2 = 1'b0;
                Pc_b2 = 1'b1;
            end

            // Precharge Bank 3
            if ((Addr[10] === 1'b1 || (Addr[10] === 1'b0 && Ba === 2'b11)) && Act_b3 === 1'b1) begin
                Act_b3 = 1'b0;
                Pc_b3 = 1'b1;
            end

            // Terminate a Write Immediately (if same bank or all banks)
            if (Data_in_enable === 1'b1 && (Bank === Ba || Addr[10] === 1'b1)) begin
                Data_in_enable = 1'b0;
            end

            // Precharge Command Pipeline for Read
            if (Cas_latency_3 === 1'b1) begin
                Command[2] = `PRECH;
                Bank_precharge[2] = Ba;
                A10_precharge[2] = Addr[10];
            end else if (Cas_latency_2 === 1'b1) begin
                Command[1] = `PRECH;
                Bank_precharge[1] = Ba;
                A10_precharge[1] = Addr[10];
            end else if (Cas_latency_1 === 1'b1) begin
                Command[0] = `PRECH;
                Bank_precharge[0] = Ba;
                A10_precharge[0] = Addr[10];
            end
        end
        
        // Burst terminate
        if (Burst_term === 1'b1) begin
            // Terminate a Write Immediately
            if (Data_in_enable == 1'b1) begin
                Data_in_enable = 1'b0;
            end

            // Terminate a Read Depend on CAS Latency
            if (Cas_latency_3 === 1'b1) begin
                Command[2] = `BST;
            end else if (Cas_latency_2 == 1'b1) begin
                Command[1] = `BST;
            end else if (Cas_latency_1 == 1'b1) begin
                Command[0] = `BST;
            end

        end
        
        // Read, Write, Column Latch
        if (Read_enable === 1'b1) begin


            // CAS Latency pipeline
            if (Cas_latency_3 == 1'b1) begin
                Command[2] = `READ;
                Col_addr[2] = Addr;
                Bank_addr[2] = Ba;
            end else if (Cas_latency_2 == 1'b1) begin
                Command[1] = `READ;
                Col_addr[1] = Addr;
                Bank_addr[1] = Ba;
            end else if (Cas_latency_1 == 1'b1) begin
                Command[0] = `READ;
                Col_addr[0] = Addr;
                Bank_addr[0] = Ba;
            end

            // Read interrupt Write (terminate Write immediately)
            if (Data_in_enable == 1'b1) begin
                Data_in_enable = 1'b0;

                // Interrupting a Write with Autoprecharge
                if (Auto_precharge[RW_interrupt_bank] == 1'b1 && Write_precharge[RW_interrupt_bank] == 1'b1) begin
                    RW_interrupt_write[RW_interrupt_bank] = 1'b1;
                    RW_interrupt_counter[RW_interrupt_bank] = 0;

                end
            end

            // Read with Auto Precharge
            if (Addr[10] == 1'b1) begin
                Auto_precharge[Ba] = 1'b1;
                Count_precharge[Ba] = 0;
                RW_interrupt_bank = Ba;
                Read_precharge[Ba] = 1'b1;
            end
        end

        // Write Command
        if (Write_enable == 1'b1) begin
            

            // Latch Write command, Bank, and Column
            Command[0] = `WRITE;
            Col_addr[0] = Addr;
            Bank_addr[0] = Ba;

            // Write interrupt Write (terminate Write immediately)
            if (Data_in_enable == 1'b1) begin
                Data_in_enable = 1'b0;

                // Interrupting a Write with Autoprecharge
                if (Auto_precharge[RW_interrupt_bank] == 1'b1 && Write_precharge[RW_interrupt_bank] == 1'b1) begin
                    RW_interrupt_write[RW_interrupt_bank] = 1'b1;
                end
            end

            // Write interrupt Read (terminate Read immediately)
            if (Data_out_enable == 1'b1) begin
                Data_out_enable = 1'b0;
                
                // Interrupting a Read with Autoprecharge
                if (Auto_precharge[RW_interrupt_bank] == 1'b1 && Read_precharge[RW_interrupt_bank] == 1'b1) begin
                    RW_interrupt_read[RW_interrupt_bank] = 1'b1;
                end
            end

            // Write with Auto Precharge
            if (Addr[10] == 1'b1) begin
                Auto_precharge[Ba] = 1'b1;
                Count_precharge[Ba] = 0;
                RW_interrupt_bank = Ba;
                Write_precharge[Ba] = 1'b1;
            end
        end

        

        // Internal Precharge or Bst
        if (Command[0] == `PRECH) begin                         // Precharge terminate a read with same bank or all banks
            if (Bank_precharge[0] == Bank || A10_precharge[0] == 1'b1) begin
                if (Data_out_enable == 1'b1) begin
                    Data_out_enable = 1'b0;
                end
            end
        end else if (Command[0] == `BST) begin                  // BST terminate a read to current bank
            if (Data_out_enable == 1'b1) begin
                Data_out_enable = 1'b0;
            end
        end

        if (Data_out_enable == 1'b0) begin
            Dq_reg <= #tOH {data_bits{1'bz}};
        end

        // Detect Read or Write command
        if (Command[0] == `READ) begin
            Bank = Bank_addr[0];
            Col = Col_addr[0];
            Col_brst = Col_addr[0];
            case (Bank_addr[0])
                2'b00 : Row = B0_row_addr;
                2'b01 : Row = B1_row_addr;
                2'b10 : Row = B2_row_addr;
                2'b11 : Row = B3_row_addr;
            endcase
            Burst_counter = 0;
            Data_in_enable = 1'b0;
            Data_out_enable = 1'b1;
        end else if (Command[0] == `WRITE) begin
            Bank = Bank_addr[0];
            Col = Col_addr[0];
            Col_brst = Col_addr[0];
            case (Bank_addr[0])
                2'b00 : Row = B0_row_addr;
                2'b01 : Row = B1_row_addr;
                2'b10 : Row = B2_row_addr;
                2'b11 : Row = B3_row_addr;
            endcase
            Burst_counter = 0;
            Data_in_enable = 1'b1;
            Data_out_enable = 1'b0;
        end

        // DQ buffer (Driver/Receiver)
        if (Data_in_enable == 1'b1) begin                                   // Writing Data to Memory
            // Array buffer
            case (Bank)
                2'b00 : Dq_dqm = Bank0 [{Row, Col}];
                2'b01 : Dq_dqm = Bank1 [{Row, Col}];
                2'b10 : Dq_dqm = Bank2 [{Row, Col}];
                2'b11 : Dq_dqm = Bank3 [{Row, Col}];
            endcase

            // Dqm operation
            if (Dqm[0] == 1'b0) begin
                Dq_dqm [ 7 :  0] = Dq [ 7 :  0];
            end
            if (Dqm[1] == 1'b0) begin
                Dq_dqm [15 :  8] = Dq [15 :  8];
            end
            if (Dqm[2] == 1'b0) begin
                Dq_dqm [23 : 16] = Dq [23 : 16];
            end
            if (Dqm[3] == 1'b0) begin
                Dq_dqm [31 : 24] = Dq [31 : 24];
            end

            // Write to memory
            case (Bank)
                2'b00 : Bank0 [{Row, Col}] = Dq_dqm;
                2'b01 : Bank1 [{Row, Col}] = Dq_dqm;
                2'b10 : Bank2 [{Row, Col}] = Dq_dqm;
                2'b11 : Bank3 [{Row, Col}] = Dq_dqm;
            endcase

  
            // Advance burst counter subroutine
            #tHZ Burst_decode;

        end else if (Data_out_enable == 1'b1) begin                         // Reading Data from Memory
            // Array buffer
            case (Bank)
                2'b00 : Dq_dqm = Bank0[{Row, Col}];
                2'b01 : Dq_dqm = Bank1[{Row, Col}];
                2'b10 : Dq_dqm = Bank2[{Row, Col}];
                2'b11 : Dq_dqm = Bank3[{Row, Col}];
            endcase

            // Dqm operation
            if (Dqm_reg0 [0] == 1'b1) begin
                Dq_dqm [ 7 :  0] = 8'bz;
            end
            if (Dqm_reg0 [1] == 1'b1) begin
                Dq_dqm [15 :  8] = 8'bz;
            end
            if (Dqm_reg0 [2] == 1'b1) begin
                Dq_dqm [23 : 16] = 8'bz;
            end
            if (Dqm_reg0 [3] == 1'b1) begin
                Dq_dqm [31 : 24] = 8'bz;
            end

            // Display debug message
            if (Dqm_reg0 !== 4'b1111) begin
                Dq_reg = #tAC Dq_dqm;
  
            end else begin
                Dq_reg = #tHZ {data_bits{1'bz}};
   
            end

            // Advance burst counter subroutine
            Burst_decode;
        end
    end

    // Burst counter decode
    task Burst_decode;
        begin
            // Advance Burst Counter
            Burst_counter = Burst_counter + 1;

            // Burst Type
            if (Mode_reg[3] == 1'b0) begin                                  // Sequential Burst
                Col_temp = Col + 1;
            end else if (Mode_reg[3] == 1'b1) begin                         // Interleaved Burst
                Col_temp[2] =  Burst_counter[2] ^  Col_brst[2];
                Col_temp[1] =  Burst_counter[1] ^  Col_brst[1];
                Col_temp[0] =  Burst_counter[0] ^  Col_brst[0];
            end

            // Burst Length
            if (Burst_length_2) begin                                       // Burst Length = 2
                Col [0] = Col_temp [0];
            end else if (Burst_length_4) begin                              // Burst Length = 4
                Col [1 : 0] = Col_temp [1 : 0];
            end else if (Burst_length_8) begin                              // Burst Length = 8
                Col [2 : 0] = Col_temp [2 : 0];
            end else begin                                                  // Burst Length = FULL
                Col = Col_temp;
            end

            // Burst Read Single Write            
            if (Write_burst_mode == 1'b1) begin
                Data_in_enable = 1'b0;
            end

            // Data Counter
            if (Burst_length_1 == 1'b1) begin
                if (Burst_counter >= 1) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_2 == 1'b1) begin
                if (Burst_counter >= 2) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_4 == 1'b1) begin
                if (Burst_counter >= 4) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_8 == 1'b1) begin
                if (Burst_counter >= 8) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end
        end
    endtask


endmodule
