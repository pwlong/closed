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

    // TESTBENCH
    tb_top testbench(
        .sys_clk,
        .sdram_clk,
        .sdram_clk_d,
        .RESETN,
        .sdr_init_done,
        .wbi
    );

    // TOP LEVEL
    sdrc_top #(
        .SDR_DW(SDR_DW),
        .SDR_BW(SDR_BW)
    ) u_dut (
        .cfg_sdr_width(CFG_SDR_WIDTH),
        .cfg_colbits(CFG_COLBITS),
        //wishbone interface
        .wbi(wbi),
        //sdram interface
        .sdram_bus(sdram_bus),
        .sdr_init_done      (sdr_init_done      ),
        // Configuration Interface
        .cfg_req_depth      (2'h3               ),  //how many req. buffer should hold
        .cfg_sdr_en         (1'b1               ),
        .cfg_sdr_mode_reg   (13'h033            ),
        .cfg_sdr_tras_d     (4'h4               ),
        .cfg_sdr_trp_d      (4'h2               ),
        .cfg_sdr_trcd_d     (4'h2               ),
        .cfg_sdr_cas        (3'h3               ),
        .cfg_sdr_trcar_d    (4'h7               ),
        .cfg_sdr_twr_d      (4'h1               ),
        .cfg_sdr_rfsh       (12'h100            ), // reduced from 12'hC35
        .cfg_sdr_rfmax      (3'h6               )
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
