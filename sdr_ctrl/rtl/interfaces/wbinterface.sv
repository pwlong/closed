interface wishbone_interface(
    input logic wb_clk_i,
    input logic  wb_rst_i
);

    parameter data_width    = 32;
    parameter address_width = 26;
    
    logic wb_stb_i;
    logic wb_we_i;
    logic [address_width-1:0] wb_addr_i;
    logic [data_width-1:0] wb_dat_i;
    logic [data_width-1:0] wb_dat_o;
    logic [data_width/8-1:0] wb_sel_i;
    logic [2:0] wb_cti_i;
    logic wb_cyc_i;
    logic wb_ack_o;

    modport master( output wb_stb_i,
                    output wb_we_i,
                    output wb_addr_i,
                    output wb_dat_i,
                    output wb_sel_i,
                    output wb_cti_i,
                    output wb_cyc_i,
                    input  wb_ack_o,
                    input  wb_clk_i,
                    input  wb_rst_i,
                    input  wb_dat_o );

    modport slave(  input  wb_stb_i,
                    input  wb_addr_i,
                    input  wb_dat_i,
                    input  wb_sel_i,
                    input  wb_cti_i,
                    input  wb_we_i,
                    input  wb_cyc_i,
                    input  wb_clk_i,
                    input  wb_rst_i,
                    output wb_ack_o,
                    output wb_dat_o );
endinterface

