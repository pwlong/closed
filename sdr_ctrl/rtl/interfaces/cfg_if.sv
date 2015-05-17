interface cfg_if();
   
    parameter SDR_REFRESH_TIMER_W   = 1;
    parameter SDR_REFRESH_ROW_CNT_W = 1;

    logic [1:0]   cfg_sdr_width       ; // 2'b00 - 32 Bit SDR, 2'b01 - 16 Bit SDR, 2'b1x - 8 Bit
    logic [1:0]   cfg_colbits         ; // 2'b00 - 8 Bit column address, 
    logic [3:0]   cfg_sdr_tras_d      ; // Active to precharge delay
    logic [3:0]   cfg_sdr_trp_d       ; // Precharge to active delay
    logic [3:0]   cfg_sdr_trcd_d      ; // Active to R/W delay
    logic         cfg_sdr_en          ; // Enable SDRAM controller
    logic [1:0]   cfg_req_depth       ; // Maximum Request accepted by SDRAM controller
    logic [12:0]  cfg_sdr_mode_reg    ;
    logic [2:0]   cfg_sdr_cas         ; // SDRAM CAS Latency
    logic [3:0]   cfg_sdr_trcar_d     ; // Auto-refresh period
    logic [3:0]   cfg_sdr_twr_d       ; // Write recovery delay
    logic [SDR_REFRESH_TIMER_W-1:0]   cfg_sdr_rfsh;
    logic [SDR_REFRESH_ROW_CNT_W-1:0] cfg_sdr_rfmax;
    wire sdr_init_done;

    modport master (
        output cfg_sdr_width       ,
        output cfg_colbits         ,
        output cfg_sdr_tras_d      ,
        output cfg_sdr_trp_d       ,
        output cfg_sdr_trcd_d      ,
        output cfg_sdr_en          ,
        output cfg_req_depth       ,
        output cfg_sdr_mode_reg    ,
        output cfg_sdr_cas         ,
        output cfg_sdr_trcar_d     ,
        output cfg_sdr_twr_d       ,
        output cfg_sdr_rfsh        ,
        output cfg_sdr_rfmax       ,
        input  sdr_init_done
    );

    modport slave (
        input  cfg_sdr_width       ,
        input  cfg_colbits         ,
        input  cfg_sdr_tras_d      ,
        input  cfg_sdr_trp_d       ,
        input  cfg_sdr_trcd_d      ,
        input  cfg_sdr_en          ,
        input  cfg_req_depth       ,
        input  cfg_sdr_mode_reg    ,
        input  cfg_sdr_cas         ,
        input  cfg_sdr_trcar_d     ,
        input  cfg_sdr_twr_d       ,
        input  cfg_sdr_rfsh        ,
        input  cfg_sdr_rfmax       ,
        output sdr_init_done
    );

endinterface
