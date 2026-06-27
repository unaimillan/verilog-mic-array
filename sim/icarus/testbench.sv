`include "config.svh"

module tb;

    logic       clk;
    logic       rst;
    wire        lr;
    wire        ws;
    wire        sck;
    logic       sd;
    wire [23:0] value;

    //------------------------------------------------------------------------

    common_top dut ();

    //------------------------------------------------------------------------

    initial
    begin
        clk = 1'b0;

        forever
            # 5 clk = ~ clk;
    end

    //------------------------------------------------------------------------

    initial
    begin
        rst <= 1'bx;
        repeat (2) @ (posedge clk);
        rst <= 1'b1;
        repeat (2) @ (posedge clk);
        rst <= 1'b0;
    end

    //------------------------------------------------------------------------

    initial
    begin
        `ifdef __ICARUS__
            $dumpvars;
        `endif

        @ (negedge rst);

        repeat (100000)
        begin
            sd <= $urandom ();
            @ (posedge clk);
        end

        $finish;
    end

endmodule
