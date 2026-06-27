module counter (
    input clk,
    input rst,

    input trig,

    output logic [63:0] counter
);

    always_ff @(posedge clk) begin
        if (rst)
        begin
            counter <= '0;
        end
        else if (trig)
        begin
            counter <= counter + 1'b1;
        end
    end

endmodule
