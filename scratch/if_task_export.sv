
interface iftest(input wire clk);
wire [7:0] address;
wire [7:0] data;
logic [2:0] state;


modport master(input clk, output address, output data);

endinterface






module exportTest(iftest i);

logic [2:0] state = 0;

task setState();
    i.state = state;
endtask

always @(posedge i.clk) begin
    state++;
    setState();
end

endmodule






module tb();

parameter  TRUE   = 1'b1;
parameter  FALSE  = 1'b0;
parameter  CLOCK_CYCLE  = 10;
localparam CLOCK_WIDTH  = CLOCK_CYCLE/2;
parameter  IDLE_CLOCKS  = 1;

logic clk, rst;

initial begin
    clk = 1'b0;
    forever #CLOCK_WIDTH clk = ~clk;
end

iftest test(clk);
exportTest ex(test);

task displayState();
    @(posedge clk) $display("state = %d", test.state);
endtask

initial begin
    repeat (10) displayState();
    $finish;
end

endmodule
