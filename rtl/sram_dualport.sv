// MIT License
// 
// Copyright (c) 2026 Maxim Kudinov
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 
// Reference:
// https://github.com/max-kudinov/SRAM-FIFO
// 
// -----------------------------------------------------------------------------

module sram_dualport #(
    parameter WIDTH  = 8,
    parameter DEPTH  = 8,
    parameter ADDR_W = $clog2(DEPTH)
) (
    input  logic              clk_i,
    input  logic              wen_i,
    input  logic              ren_i,
    input  logic [ADDR_W-1:0] waddr_i,
    input  logic [ADDR_W-1:0] raddr_i,
    input  logic [ WIDTH-1:0]  data_i,
    output logic [ WIDTH-1:0]  data_o
);

    logic [WIDTH-1:0] sram [DEPTH];

    always_ff @(posedge clk_i) begin
        if (wen_i) begin
            sram[waddr_i] <= data_i;
        end
    end

    always_ff @(posedge clk_i) begin
        if (ren_i) begin
            data_o <= sram[raddr_i];
        end
    end

endmodule
