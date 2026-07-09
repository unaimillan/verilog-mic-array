module w5500_cpu_driver_tb;

    //------------------------------------------------------------------------

    localparam TIMEOUT = 5000;

    //------------------------------------------------------------------------

    logic clk;

    initial
    begin
        clk = '0;

        forever
            # 500 clk = ~ clk;
    end

    logic rst;

    initial
    begin
        rst <= 'x;
        repeat (2) @ (posedge clk);
        rst <= '1;
        repeat (2) @ (posedge clk);
        rst <= '0;
    end

    //------------------------------------------------------------------------

    logic a, half_b;

    w5500_ucpu_driver
    # (
        .DATA_W ( 32 )
    )
    ucpu_driver_inst
    (
        .clk      ( clk ) , // input
        .rst      ( rst ) , // input
        .in_valid (  ) , // input
        .in_ready (  ) , // output
        .in_data  (  ) , // input  [DATA_W - 1:0]
        .spi_clk  (  ) , // output
        .spi_cs_n (  ) , // output
        .spi_mosi (  ) , // output
        .spi_miso (  )   // input
    );

    //------------------------------------------------------------------------

    // Monitor

    bit was_reset = 1'b0;
    always @ (posedge clk) if (rst) was_reset <= 1'b1;

    int n_orig_tokens = 0,
        n_half_tokens = 0;

    always @ (posedge clk)
        if (~ rst & was_reset)
        begin
            n_orig_tokens <= n_orig_tokens + 32' (a);
            n_half_tokens <= n_half_tokens + 32' (half_b);
        end

    //------------------------------------------------------------------------

    initial
    begin
        `ifdef __ICARUS__
            // Uncomment the following line
            // to generate a VCD file and analyze it using GTKwave or Surfer

            $dumpvars;
        `endif

        @ (negedge rst);

        repeat (100)
        begin
            a <= 1' ($urandom ());
            @ (posedge clk);
        end

        a <= 1'b0;

        repeat (200)
            @ (posedge clk);

        //--------------------------------------------------------------------

        // if (n_half_tokens !== n_orig_tokens / 2)
        // begin
        //     $display("FAIL %s", `__FILE__);
        //     $display("++ INPUT    => {%s}",
        //                      `PD(n_orig_tokens));

        //     $display("++ TEST     => {%s}",
        //                      `PD(n_half_tokens));
        //     $finish(1);
        // end

        // $display ("PASS %s", `__FILE__);
        // $finish;
    end
    
    //----------------------------------------------------------------------

    initial
    begin
        repeat (TIMEOUT) @ (posedge clk);
        $display ("FAIL %s: timeout!", `__FILE__);
        $finish;
    end

endmodule
