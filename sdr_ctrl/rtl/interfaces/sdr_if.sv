interface sdr_bus #(
  parameter  SDR_DW   = 16,         // SDRAM Data Width 
  parameter  SDR_BW   = 2,          // SDRAM Byte Width
  // Parameters to describe timing attributes of interface
  parameter BURST_LENGTH = 1,
  parameter TRAS         = 1,
  parameter TCAS         = 1,
  parameter TRCD         = 1,
  parameter TRP          = 1 
)(
  input logic sdram_clk,                 // SDRAM Clock
  input logic sdram_clk_d,               // Delayed clock
  input logic sdram_resetn,
  input logic sdr_init_done
);
  logic               sdr_cke;      // SDRAM Clock
  logic               sdr_cs_n;     // SDRAM Chip Select
  logic 	          sdr_ras_n;    // SDRAM ras
  logic 	          sdr_cas_n;    // SDRAM cas
  logic 	          sdr_we_n;     // SDRAM write enable
  wire [SDR_DW-1:0]  sdr_dq;       // SDRAM DATA                               
  logic [SDR_BW-1:0]  sdr_dqm;      // SDRAM Data Mask
  logic [1:0]         sdr_ba;       // SDRAM Bank Enable
  logic [12:0] 		  sdr_addr;     // SDRAM Address
  logic [SDR_DW-1:0]  sdr_din;  // SDRAM Data Input
  logic [SDR_DW-1:0]  sdr_dout;     // SDRAM Data Output
  logic [SDR_BW-1:0]  sdr_den_n;    // SDRAM Data Output enable

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
  
  typedef enum logic [3:0] {
   INITIALIZING, IDLE, REFRESHING, ACTIVATING, ACTIVE, RD, RD_W_PC, WR, WR_W_PC, PRECHARGING
  } bankState_t;

  // commands in table 14, page 25 of dram datasheet
  typedef enum bit [3:0] {
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
  
  //Current Command
  cmd_t cmd;
  assign cmd  = cmd_t'({sdr_cs_n, sdr_ras_n, sdr_cas_n, sdr_we_n});

  logic aux_cmd;
  assign aux_cmd  = sdr_addr[10];
  
  //Acceptable Commands
  bit cmd_nop;
  bit cmd_idle;
  bit cmd_act;
  bit cmd_xfr;
  assign cmd_nop   = (cmd[3] === 1'b1 | cmd === CMD_NOP);
  assign cmd_idle  = (cmd_nop | cmd === CMD_ACTIVE | cmd === CMD_AUTO_REFRESH | cmd === CMD_LOAD_MODE_REGISTER | cmd === CMD_PRECHARGE);
  assign cmd_act   = (cmd_nop | cmd === CMD_READ | cmd === CMD_WRITE | cmd === CMD_PRECHARGE);
  assign cmd_xfr   = (cmd_act | cmd === CMD_BURST_TERMINATE);

  task doCommandAssert(bankState_t bankState, bit cmdIsLegal);
    begin
        assert(cmdIsLegal)
            $display("sdrc_if: COMMAND ASSERTION PASS - STATE: %p   COMMAND: %p", bankState, cmd);
        else
            $display("sdrc_if: COMMAND ASSERTION FAIL - STATE: %p   COMMAND: %p", bankState, cmd);
    end
  endtask
  

  bankState_t bank0State, bank0NextState;

  // Used to keep track of counts while in specific states
  integer activatingCounter = 0;
  integer refreshingCounter = 0;
  integer readingCounter    = 0;
  integer writingCounter    = 0;
  integer prechargeCounter  = 0;

  // Bank 0 FSM Sequential Logic
  always_ff @(posedge sdram_clk) begin
    if (~sdram_resetn)
        bank0State <= INITIALIZING;
    else
        bank0State <= bank0NextState;
  end

  // Keep track of length of time
  // in certain states
  always_ff @(posedge sdram_clk) begin
    case(bank0State)
        REFRESHING:  refreshingCounter <= refreshingCounter + 1;
        ACTIVATING:  activatingCounter <= activatingCounter + 1;
        RD:          readingCounter    <= readingCounter + 1;
        RD_W_PC:     readingCounter    <= readingCounter + 1;
        WR:          writingCounter    <= writingCounter + 1;
        WR_W_PC:     writingCounter    <= writingCounter + 1;
        PRECHARGING: prechargeCounter  <= prechargeCounter + 1;
        default: begin
                      activatingCounter <= 0;
                      refreshingCounter <= 0;
                      readingCounter    <= 0;
                      writingCounter    <= 0;
                      prechargeCounter  <= 0;
                 end
    endcase
  end

  // Next State Combinational Logic
  always_comb begin
    case(bank0State)
        INITIALIZING :  begin
                            if(sdr_init_done)
                                bank0NextState = IDLE;
                            else
                                bank0NextState = INITIALIZING;
                        end
        IDLE         :  begin
                            if((cmd === CMD_ACTIVE) & (sdr_ba === 2'b00))
                                bank0NextState = ACTIVATING;
                            else if ((cmd === CMD_AUTO_REFRESH) & (sdr_ba === 2'b00))
                                bank0NextState = REFRESHING;
                            else
                                bank0NextState = IDLE;
                        end
        REFRESHING   :  begin
                            bank0NextState = IDLE;
                        end
        ACTIVATING   :  begin
                            if (activatingCounter >= TRCD)
                                bank0NextState = ACTIVE;
                            else
                                bank0NextState = ACTIVATING;
                        end
        ACTIVE       :  begin
                            if     ((cmd === CMD_WRITE)     & (sdr_ba === 2'b00))
                                if (aux_cmd)
                                    bank0NextState = WR_W_PC;
                                else
                                    bank0NextState = WR;
                            else if((cmd === CMD_READ)      & (sdr_ba === 2'b00))
                                if (aux_cmd)
                                    bank0NextState = RD_W_PC;
                                else
                                    bank0NextState = RD;
                            else if((cmd === CMD_PRECHARGE) & (sdr_ba === 2'b00))
                                bank0NextState = PRECHARGING;
                            else
                                bank0NextState = ACTIVE;
                        end
        RD           :  begin
                            if     ((cmd === CMD_WRITE)     & (sdr_ba === 2'b00))
                                bank0NextState = WR;
                            else if((cmd === CMD_READ)      & (sdr_ba === 2'b00))
                                bank0NextState = RD;
                            else if((cmd === CMD_PRECHARGE) & (sdr_ba === 2'b00 | aux_cmd))
                                bank0NextState = PRECHARGING;
                            else if((cmd === CMD_BURST_TERMINATE) & (sdr_ba === 2'b00))
                                bank0NextState = ACTIVE;
                            else
                                if (readingCounter >= BURST_LENGTH)
                                    bank0NextState = ACTIVE;
                                else
                                    bank0NextState = RD;
                        end
        RD_W_PC      :  begin
                           if (readingCounter >= BURST_LENGTH)
                               bank0NextState = PRECHARGING;
                           else
                               bank0NextState = RD_W_PC;
                        end
        WR           :  begin
                            if     ((cmd === CMD_WRITE)     & (sdr_ba === 2'b00))
                                bank0NextState = WR;
                            else if((cmd === CMD_READ)      & (sdr_ba === 2'b00))
                                bank0NextState = RD;
                            else if((cmd === CMD_PRECHARGE) & (sdr_ba === 2'b00 | aux_cmd))
                                bank0NextState = PRECHARGING;
                            else if((cmd === CMD_BURST_TERMINATE) & (sdr_ba === 2'b00))
                                bank0NextState = ACTIVE;
                            else
                                if (writingCounter >= BURST_LENGTH)
                                    bank0NextState = ACTIVE;
                                else
                                    bank0NextState = WR;
                        end
        WR_W_PC      :  begin
                            if (writingCounter >= BURST_LENGTH)
                                bank0NextState = PRECHARGING;
                            else
                                bank0NextState = WR_W_PC;
                        end
        PRECHARGING  :  begin
                            bank0NextState = IDLE;
                        end
    endcase
  end

  always@ (posedge sdram_clk) begin
    //Bank 0 Asserts
    if (sdr_ba === 2'b00) begin
        case (bank0State)
            INITIALIZING:$display("sdrc_if: Init State");
            IDLE:        doCommandAssert(bank0State, cmd_idle);
            REFRESHING:  doCommandAssert(bank0State, cmd_nop);
            ACTIVATING:  doCommandAssert(bank0State, cmd_nop);
            ACTIVE:      doCommandAssert(bank0State, cmd_act);
            RD:          doCommandAssert(bank0State, cmd_xfr);
            WR:          doCommandAssert(bank0State, cmd_xfr);
            RD_W_PC:     doCommandAssert(bank0State, cmd_nop);
            WR_W_PC:     doCommandAssert(bank0State, cmd_nop);
            PRECHARGING: doCommandAssert(bank0State, cmd_nop);
        endcase
    end
  end

endinterface
