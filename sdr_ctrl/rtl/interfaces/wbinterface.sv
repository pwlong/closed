interface wishbone_interface(
    input logic wb_clk_i,
    input logic wb_rst_i,
    input logic wb_sdram_clk_i
);
    //pragma attribute wishbone_interface partition_interface_xif

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
                    input  wb_dat_o);
                    //task   read(),
                    //task   write() );

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

    task write; // pragma tbx xtf
      input [31:0] Address;
      input [7:0]  bl;
      input [31:0] data;

      begin
         @ (negedge wb_clk_i);
         //@ (posedge wb_clk_i);
         wb_stb_i        <= 1;
         wb_cyc_i        <= 1;
         wb_we_i         <= 1;
         wb_sel_i        <= 4'b1111;
         wb_addr_i       <= Address;
         wb_dat_i        <= data;

         do begin
            @ (negedge wb_clk_i); 
	    //@ (posedge wb_clk_i);
         end while(wb_ack_o == 1'b0);
         @ (negedge wb_clk_i);
         //@ (posedge wb_clk_i);
         wb_stb_i        <= 0;
         wb_cyc_i        <= 0;
         wb_we_i         <= 'hz;
         wb_sel_i        <= 'hz;
         wb_addr_i       <= 'hz;
         wb_dat_i        <= 'hz;
      end
    endtask
    
    task read; //pragma tbx xtf
      input [31:0] Address;
      input [7:0] bl;
      output [31:0] data;

      begin
         @ (negedge wb_clk_i);
         //@ (posedge wb_clk_i);
         wb_stb_i        <= 1;
         wb_cyc_i        <= 1;
         wb_we_i         <= 0;
         wb_addr_i       <= Address;

         do begin
             @ (negedge wb_clk_i);
         end while(wb_ack_o == 1'b0);
         data = wb_dat_o;
         @ (negedge wb_clk_i);
         //@ (posedge wb_sdram_clk_i);
         wb_stb_i        <= 0;
         wb_cyc_i        <= 0;
         wb_we_i         <= 'hz;
         wb_addr_i       <= 'hz;
      end
    endtask
endinterface

