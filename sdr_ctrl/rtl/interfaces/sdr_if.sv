`include "sdr_pack.sv"
interface sdr_bus #(
  parameter  SDR_DW   = 16,         // SDRAM Data Width 
  parameter  SDR_BW   = 2,          // SDRAM Byte Width
  // Parameters to describe timing attributes of interface
  parameter BURST_LENGTH = 1, // Read/Write Burst Length
  parameter TRAS         = 1, // Activate to Precharge Delay
  parameter TCAS         = 1, // CAS Delay
  parameter TRCD         = 1, // Ras to Cas Delay
  parameter TRP          = 1, // Precharge Command Period
  parameter TWR          = 1//, // Write Recover Time
  //parameter VERBOSE      = 1
)(
  input logic sdram_clk,          // SDRAM Clock
  input logic sdram_clk_d,        // Delayed clock
  input logic sdram_resetn,
  input logic sdr_init_done
);
  logic               sdr_cke;     // SDRAM Clock
  logic               sdr_cs_n;    // SDRAM Chip Select
  logic 	          sdr_ras_n;   // SDRAM ras
  logic 	          sdr_cas_n;   // SDRAM cas
  logic 	          sdr_we_n;    // SDRAM write enable
  wire [SDR_DW-1:0]  sdr_dq;       // SDRAM DATA                               
  logic [SDR_BW-1:0]  sdr_dqm;     // SDRAM Data Mask
  logic [1:0]         sdr_ba;      // SDRAM Bank Enable
  logic [12:0] 		  sdr_addr;    // SDRAM Address
  logic [SDR_DW-1:0]  sdr_din;     // SDRAM Data Input
  logic [SDR_DW-1:0]  sdr_dout;    // SDRAM Data Output
  logic [SDR_BW-1:0]  sdr_den_n;   // SDRAM Data Output enable
  logic VERBOSE = 1;
  logic sdr_fsm_en = 1;

  // Tristate logic for the din/dout pins on the core
  assign   sdr_dq = (&sdr_den_n == 1'b0) ? sdr_dout :  {SDR_DW{1'bz}};
  assign   sdr_din = sdr_dq;

  modport ctrltop (
    inout  sdr_dq,
    output sdr_addr,
    output sdr_ba,
    output sdr_cke,
    output sdr_cs_n,
    output sdr_ras_n,
    output sdr_cas_n,
    output sdr_we_n,
    output sdr_dqm,
    input  sdram_clk,
    input  sdram_resetn
  );

  modport ctrlcore (
    output sdr_addr,
    output sdr_ba,
    output sdr_cke,
    output sdr_cs_n,
    output sdr_ras_n,
    output sdr_cas_n,
    output sdr_we_n,
    output sdr_dqm,
    output sdr_dout,
    output sdr_den_n,
    input  sdr_din,
    input  sdram_clk,
    input  sdram_resetn
  );
  
  modport ram (
    inout sdr_dq,
    input sdr_addr,
    input sdr_ba,
    input sdr_cke,
    input sdr_cs_n,
    input sdr_ras_n,
    input sdr_cas_n,
    input sdr_we_n,
    input sdr_dqm,
    input sdram_clk_d,
    input sdram_resetn
  );
  
  import sdr_pack::*;
  
  //Current Command
  cmd_t cmd;
  assign cmd  = cmd_t'({sdr_cs_n, sdr_ras_n, sdr_cas_n, sdr_we_n});

  logic aux_cmd;
  assign aux_cmd  = sdr_addr[10];
  
  int assertFailCount = 0;
  
  //Acceptable Commands
  bit cmd_nop;
  bit cmd_idle;
  bit cmd_act;
  bit cmd_xfr;
  assign cmd_nop   = (cmd[3] === 1'b1 | cmd === CMD_NOP);
  assign cmd_idle  = (cmd_nop | cmd === CMD_ACTIVE | cmd === CMD_AUTO_REFRESH | cmd === CMD_LOAD_MODE_REGISTER | cmd === CMD_PRECHARGE);
  assign cmd_act   = (cmd_nop | cmd === CMD_READ | cmd === CMD_WRITE | cmd === CMD_PRECHARGE);
  assign cmd_xfr   = (cmd_act | cmd === CMD_BURST_TERMINATE);
  bit crossBankLegalCommand;
  assign crossBankLegalCommand = (cmd_nop | cmd === CMD_ACTIVE | cmd === CMD_READ | cmd === CMD_WRITE | cmd === CMD_PRECHARGE);

  task doCommandAssert(integer bNum, bankState_t bankState, bit cmdIsLegal);
    begin
        assert(cmdIsLegal) begin
          if (VERBOSE)
            $display("sdrc_if: BANK: %p COMMAND ASSERTION PASS - STATE: %p   COMMAND: %p", bNum, bankState, cmd);
        end else begin
          if (VERBOSE)
            $display("sdrc_if: BANK: %p COMMAND ASSERTION FAIL - STATE: %p   COMMAND: %p", bNum, bankState, cmd);
          assertFailCount++;
        end
    end
  endtask

  task doCrossBankCommandAssert(integer banki, integer bankj, bankState_t bankiState, bit cmdIsLegal);
    begin
        assert(cmdIsLegal)
        else begin
          if (VERBOSE)
            $display("sdrc_if: Bank %p In State %p, Command %p issued to bank %p FAIL", banki, bankiState, cmd, bankj);
        end

    end
  endtask
  
  // Array of 4 values, one for each bank
  bankState_t bankState[0:3];
  bankState_t bankNextState[0:3];

  // Used to keep track of counts while in specific states
  integer activatingCounter[0:3] = '{0,0,0,0};
  integer refreshingCounter[0:3] = '{0,0,0,0};
  integer readingCounter[0:3]    = '{0,0,0,0};
  integer writingCounter[0:3]    = '{0,0,0,0};
  integer prechargeCounter[0:3]  = '{0,0,0,0};
  
  // track the number of times each state was entered
  integer        idleCount[0:3] = '{0,0,0,0};
  //integer        initCount[0:3] = '{0,0,0,0};
  integer  activatingCount[0:3] = '{0,0,0,0};
  integer      activeCount[0:3] = '{0,0,0,0};
  integer  refreshingCount[0:3] = '{0,0,0,0};
  integer          wrCount[0:3] = '{0,0,0,0};
  integer          rdCount[0:3] = '{0,0,0,0};
  integer       wrwpcCount[0:3] = '{0,0,0,0};
  integer       rdwpcCount[0:3] = '{0,0,0,0};
  integer prechargingCount[0:3] = '{0,0,0,0};


  // Bank FSM Sequential Logic
  /*always_ff @(posedge sdram_clk) begin
    if (sdr_fsm_en) begin
    for (int i = 0; i < 4; i++) begin
        if (~sdram_resetn)
            bankState[i] <= INITIALIZING;
        else
            bankState[i] <= bankNextState[i];
    end
    end
  end*/
  always_ff @(posedge sdram_clk) begin
    if (sdr_fsm_en) begin
    for (int i = 0; i < 4; i++) begin
        if (~sdram_resetn)
            bankState[i] <= INITIALIZING;
        else begin
            if (bankNextState[i] !== bankState[i]) begin
                unique case (bankNextState[i])
                  IDLE:        idleCount[i]        <= idleCount[i] + 1;
                  REFRESHING:  refreshingCount[i]  <= refreshingCount[i] + 1;
                  ACTIVE:      activeCount[i]      <= activeCount[i] + 1;
                  ACTIVATING:  activatingCount[i]  <= activatingCount[i] + 1;
                  WR:          wrCount[i]          <= wrCount[i] + 1;
                  RD:          rdCount[i]          <= rdCount[i] + 1;
                  WR_W_PC:     wrwpcCount[i]       <= wrwpcCount[i] + 1;
                  RD_W_PC:     rdwpcCount[i]       <= rdwpcCount[i] + 1;
                  PRECHARGING: prechargingCount[i] <= prechargingCount[i] + 1;
                endcase
            end
            bankState[i] <= bankNextState[i];
        end
    end
    end
  end

  // Keep track of length of time
  // in certain states
  always_ff @(posedge sdram_clk) begin
    for (int i = 0; i < 4; i++) begin
        case(bankState[i])
            REFRESHING:  refreshingCounter[i] <= refreshingCounter[i] + 1;
            ACTIVATING:  activatingCounter[i] <= activatingCounter[i] + 1;
            RD:          readingCounter[i]    <= readingCounter[i] + 1;
            RD_W_PC:     readingCounter[i]    <= readingCounter[i] + 1;
            WR:          writingCounter[i]    <= writingCounter[i] + 1;
            WR_W_PC:     writingCounter[i]    <= writingCounter[i] + 1;
            PRECHARGING: prechargeCounter[i]  <= prechargeCounter[i] + 1;
            default: begin
                          activatingCounter[i] <= 0;
                          refreshingCounter[i] <= 0;
                          readingCounter[i]    <= 0;
                          writingCounter[i]    <= 0;
                          prechargeCounter[i]  <= 0;
                     end
        endcase
    end
  end

  // Next State Combinational Logic
  always_comb begin
    if (sdr_fsm_en) begin
    for (int i = 0; i < 4; i++) begin
        case(bankState[i])
            INITIALIZING :  begin
                                if(sdr_init_done)
                                    bankNextState[i] = IDLE;
                                else
                                    bankNextState[i] = INITIALIZING;
                            end
            IDLE         :  begin
                                if((cmd === CMD_ACTIVE) & (sdr_ba === i))
                                    bankNextState[i] = ACTIVATING;
                                else if ((cmd === CMD_AUTO_REFRESH) & (sdr_ba === i))
                                    bankNextState[i] = REFRESHING;
                                else
                                    bankNextState[i] = IDLE;
                            end
            REFRESHING   :  begin
                                bankNextState[i] = IDLE;
                            end
            ACTIVATING   :  begin
                                if (activatingCounter[i] >= TRCD-1)
                                    bankNextState[i] = ACTIVE;
                                else
                                    bankNextState[i] = ACTIVATING;
                            end
            ACTIVE       :  begin
                                if     ((cmd === CMD_WRITE)     & (sdr_ba === i))
                                    if (aux_cmd)
                                        bankNextState[i] = WR_W_PC;
                                    else
                                        bankNextState[i] = WR;
                                else if((cmd === CMD_READ)      & (sdr_ba === i))
                                    if (aux_cmd)
                                        bankNextState[i] = RD_W_PC;
                                    else
                                        bankNextState[i] = RD;
                                else if((cmd === CMD_PRECHARGE) & (sdr_ba === i | aux_cmd))
                                    bankNextState[i] = PRECHARGING;
                                else
                                    bankNextState[i] = ACTIVE;
                            end
            RD           :  begin
                                if     ((cmd === CMD_WRITE)     & (sdr_ba === i))
                                    bankNextState[i] = WR;
                                else if((cmd === CMD_READ)      & (sdr_ba === i))
                                    bankNextState[i] = RD;
                                else if((cmd === CMD_PRECHARGE) & (sdr_ba === i | aux_cmd))
                                    bankNextState[i] = PRECHARGING;
                                else if((cmd === CMD_BURST_TERMINATE) & (sdr_ba === i))
                                    bankNextState[i] = ACTIVE;
                                else
                                    if (readingCounter[i] >= BURST_LENGTH - 1)
                                        bankNextState[i] = ACTIVE;
                                    else
                                        bankNextState[i] = RD;
                            end
            RD_W_PC      :  begin
                               if (readingCounter[i] >= BURST_LENGTH - 1)
                                   bankNextState[i] = PRECHARGING;
                               else
                                   bankNextState[i] = RD_W_PC;
                            end
            WR           :  begin
                                if     ((cmd === CMD_WRITE)     & (sdr_ba === i))
                                    bankNextState[i] = WR;
                                else if((cmd === CMD_READ)      & (sdr_ba === i))
                                    bankNextState[i] = RD;
                                else if((cmd === CMD_PRECHARGE) & (sdr_ba === i | aux_cmd))
                                    bankNextState[i] = PRECHARGING;
                                else if((cmd === CMD_BURST_TERMINATE) & (sdr_ba === i))
                                    bankNextState[i] = ACTIVE;
                                else
                                    if (writingCounter[i] >= BURST_LENGTH - 1)
                                        bankNextState[i] = ACTIVE;
                                    else
                                        bankNextState[i] = WR;
                            end
            WR_W_PC      :  begin
                                if (writingCounter[i] >= BURST_LENGTH - 1)
                                    bankNextState[i] = PRECHARGING;
                                else
                                    bankNextState[i] = WR_W_PC;
                            end
            PRECHARGING  :  begin
                                if (prechargeCounter[i] >= TRP - 1)
                                    bankNextState[i] = IDLE;
                                else
                                    bankNextState[i] = PRECHARGING;
                            end
        endcase
    end
    end
  end

  // Validates commands are legal for each bank in each state
  // These are for Bank N -> Bank N checks
  always@ (posedge sdram_clk) begin
    for(int i = 0; i < 4; i++) begin
        if ((sdr_ba === i) | (aux_cmd & cmd === CMD_PRECHARGE)) begin
            case (bankState[i])
                INITIALIZING:$display("sdrc_if: Init State");
                IDLE:        doCommandAssert(i, bankState[i], cmd_idle);
                REFRESHING:  doCommandAssert(i ,bankState[i], cmd_nop);
                ACTIVATING:  doCommandAssert(i, bankState[i], cmd_nop);
                ACTIVE:      doCommandAssert(i, bankState[i], cmd_act);
                RD:          doCommandAssert(i, bankState[i], cmd_xfr);
                WR:          doCommandAssert(i, bankState[i], cmd_xfr);
                RD_W_PC:     doCommandAssert(i, bankState[i], cmd_nop);
                WR_W_PC:     doCommandAssert(i, bankState[i], cmd_nop);
                PRECHARGING: doCommandAssert(i, bankState[i], cmd_nop);
            endcase
        end
    end
  end

  // Validates commands are legal for banks in each state
  // These are for Bank N -> Bank M checks
  always@ (posedge sdram_clk) begin
    for(int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        if (i !== j) begin
            if (((sdr_ba === j) | (aux_cmd & cmd === CMD_PRECHARGE)) & (cmd !== CMD_BURST_TERMINATE)) begin
                case (bankState[i])
                    ACTIVATING:  doCrossBankCommandAssert(i,j,bankState[i],crossBankLegalCommand);
                    ACTIVE:      doCrossBankCommandAssert(i,j,bankState[i],crossBankLegalCommand);
                    RD:          doCrossBankCommandAssert(i,j,bankState[i],crossBankLegalCommand);
                    WR:          doCrossBankCommandAssert(i,j,bankState[i],crossBankLegalCommand);
                    RD_W_PC:     doCrossBankCommandAssert(i,j,bankState[i],crossBankLegalCommand);
                    WR_W_PC:     doCrossBankCommandAssert(i,j,bankState[i],crossBankLegalCommand);
                    PRECHARGING: doCrossBankCommandAssert(i,j,bankState[i],crossBankLegalCommand);
                endcase
            end
        end
      end
    end
  end

  // Define sequences that describe timing violations
  // and assert that they are never observed
  genvar k;
  generate
    for (k = 0; k < 4; k++) begin
      if (TRAS > 1) begin
        sequence trasViolation;
            @(posedge sdram_clk) ((cmd === CMD_ACTIVE) & (sdr_ba === k)) ##[1:TRAS-1]
                                 (((sdr_ba === k) | aux_cmd) & (cmd === CMD_PRECHARGE));
          endsequence
          assert property (not trasViolation) else $display("sdrc_if: Bank %p Tras violation", k);
      end
      if (TRCD > 1) begin
          sequence trcdViolation;
            @(posedge sdram_clk) ((cmd === CMD_ACTIVE) & (sdr_ba === k)) ##[1:TRCD-1]
                                 ((sdr_ba === k) & (cmd === CMD_WRITE) | (cmd === CMD_READ));
          endsequence
          assert property (not trcdViolation) else $display("sdrc_if: Bank %p Trcd violation", k);
      end
      if (TRP > 1) begin
          sequence trpViolation;
            @(posedge sdram_clk) ((cmd === CMD_PRECHARGE)  & ((sdr_ba === k) | aux_cmd) & (bankState[k] !== IDLE)) ##[1:TRP-1]
                                 ((sdr_ba === k) & (~cmd_nop));
          endsequence
          assert property (not trpViolation)  else $display("sdrc_if: Bank %p Trp  violation", k);
      end
      if (TWR > 1) begin
          sequence twrViolation;
            @(posedge sdram_clk) ((cmd === CMD_WRITE) & (sdr_ba === k)) ##[1:TWR-1]
                                 (((sdr_ba === k) | aux_cmd) & (cmd === CMD_PRECHARGE));
          endsequence
          assert property (not twrViolation)  else $display("sdrc_if: Bank %p Twr  violation", k);
      end
    end
  endgenerate

endinterface
