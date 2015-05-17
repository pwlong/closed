`include "sdrc_define.v"
module top;

    // DEFINE TEST PARAMETERS
    localparam dw = 32; // application data width
    localparam tw = 8;  // tag id width
    localparam bl = 5;  // burst length width
`ifdef SDR_32BIT
    localparam    SDR_DW          = 32;           // SDRAM Data Width
    localparam    CFG_SDR_WIDTH   = 2'b00;
`elsif SDR_16BIT
    localparam    SDR_DW          = 16;           // SDRAM Data Width
    localparam    CFG_SDR_WIDTH   = 2'b01;
`else  // 8 BIT SDRAM
    localparam    SDR_DW          = 08;           // SDRAM Data Width
    localparam    CFG_SDR_WIDTH   = 2'b10;
`endif
    localparam    SDR_BW          = (SDR_DW / 8); // SDRAM Byte Width
    localparam    CFG_COLBITS     = 2'b00;        // 8 Bit Column Address

    // WIRE DECLARATIONS
    wire sys_clk,sdram_clk,sdram_clk_d,RESETN;
    wire sdr_init_done;

    // INTERFACE DECLARATIONS
    wishbone_interface #(.data_width(dw)) wbi(.wb_clk_i(sys_clk),.wb_rst_i(!RESETN));
    sdr_bus #(SDR_DW,SDR_BW) sdram_bus (sdram_clk, sdram_clk_d, RESETN);
    cfg_if #(.SDR_REFRESH_TIMER_W(`SDR_RFSH_TIMER_W),
             .SDR_REFRESH_ROW_CNT_W(`SDR_RFSH_ROW_CNT_W)) cfg();

    // TESTBENCH
    tb_top #(
        .CFG_SDR_WIDTH(CFG_SDR_WIDTH),
        .CFG_COLBITS(CFG_COLBITS)
    ) testbench
    (
        .sys_clk,
        .sdram_clk,
        .sdram_clk_d,
        .RESETN,
        .wbi,
        .cfg
    );

    // TOP LEVEL
    sdrc_top #(
        .SDR_DW(SDR_DW),
        .SDR_BW(SDR_BW)
    ) u_dut (
        //wishbone interface
        .wbi,
        //sdram interface
        .sdram_bus,
        // configuration bus
        .cfg
    );

    // DIMM MODEL
    `ifdef SDR_32BIT
    mt48lc2m32b2 #(.data_bits(32)) u_sdram32 (.sdram_bus(sdram_bus));
    `elsif SDR_16BIT
    IS42VM16400K u_sdram16 (.sdram_bus(sdram_bus));
    `else 
    mt48lc8m8a2 #(.data_bits(8)) u_sdram8 (.sdram_bus(sdram_bus));
    `endif


endmodule
