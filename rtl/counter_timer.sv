module counter_timer
#(
    parameter logic COUNT_DOWN               = 1'b0,
              int   MAX_VALUE                = 16,
              int   CNT_W                    = $clog2( MAX_VALUE + 1),
              logic [ CNT_W - 1 : 0] MAX_CNT = MAX_VALUE
) (
    input                    clk,
    input                    rst,
    input                    soft_rst,
    input                    start,
    input                    tick_valid,
    output logic             finished,
    output logic [CNT_W-1:0] counter,
    output logic [CNT_W-1:0] counter_next
);

    logic timer_enabled;

    always_comb
    begin
        finished = COUNT_DOWN ? ( counter == '0 ) : ( counter == MAX_CNT );
        
        if ( finished )
            counter_next = COUNT_DOWN ? MAX_CNT : '0;
        else
            counter_next = COUNT_DOWN ? ( counter - 1'b1 ) : ( counter + 1'b1 );
    end

    always_ff @( posedge clk ) begin
        if ( rst )
        begin
            timer_enabled <= '0;
        end
        else if ( soft_rst )
        begin
            timer_enabled <= '0;
        end
        else
        begin
            if ( start )
            begin
                timer_enabled <= '1;
            end
            else if ( finished )
            begin
                timer_enabled <= '0;
            end
        end 
    end

    always_ff @( posedge clk ) begin
        if ( rst )
        begin
            counter <= COUNT_DOWN ? MAX_CNT : '0;
        end
        else if ( soft_rst )
        begin
            counter <= COUNT_DOWN ? MAX_CNT : '0;
        end
        else if ( start | timer_enabled | tick_valid )
        begin
            counter <= counter_next;
        end
    end

endmodule
