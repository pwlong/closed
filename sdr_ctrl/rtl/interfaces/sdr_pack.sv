
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
