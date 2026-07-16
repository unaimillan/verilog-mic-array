// MIT License
//
// ------------------------------------------------------------------------------
//
// Copyright (c) 2013-2023 Yuri Panchul, Victor Prutyanov, Maria Belichenko,
// Vladimir Efimov, Dmitry Smekhov, Sergey Chusov, Dmitry Petrenko, Boris
// Krasniansky, Alexander Kirichenko, Alexander Ryabov, Lilia Kirakosyan,
// Victor Vyazovtsev, Digital Design School, ChipEXPO and others.
//
// ------------------------------------------------------------------------------
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
// https://github.com/yuri-panchul/basics-graphics-music/blob/438257422ca9c7e4691587306624d1580fe4377b/peripherals/inmp441_mic_i2s_receiver.sv
//
// -----------------------------------------------------------------------------

// Asynchronous reset here is needed for one of FPGA boards we use

`include "config.svh"

module inmp441_mic_i2s_receiver_with_valid
# (
    parameter clk_mhz = 50
)
(
    input               clk,
    input               rst,

    //--------------------------------------------------------------------------
    // Internal interface
    //--------------------------------------------------------------------------

    input               lr_ch,

    output logic        sample_valid,
    output logic [23:0] sample,

    //--------------------------------------------------------------------------
    // External I2S interface
    //--------------------------------------------------------------------------

    output              lr,
    output logic        ws,
    output              sck,
    input               sd
);

    assign lr = lr_ch;

    //--------------------------------------------------------------------------

    logic clk_en;

    generate
        if (clk_mhz == 100)
        begin : clk_100
            always_ff @ (posedge clk or posedge rst)
                if (rst)
                    clk_en <= '0;
                else
                    clk_en <= ~ clk_en;
        end
        else
        begin : not_clk_100
            assign clk_en = '1;
        end
    endgenerate

    //------------------------------------------------------------------------

    logic [8:0] cnt;

    always_ff @ (posedge clk or posedge rst)
        if (rst)
            cnt <= '0;
        else if (clk_en)
            cnt <= cnt + 1'd1;

    //------------------------------------------------------------------------

    assign sck = cnt [3];                // 50 MHz / 16   = 3.13 MHz

    always_ff @ (posedge clk or posedge rst)
        if (rst)
            ws <= 1'b1;
        else if (clk_en & cnt == 9'd15)  // 50 MHz / 1024 = 48.8  KHz
            ws <= ~ ws;

    wire sample_bit
        =    ws == lr
          && cnt >= 9'd39                // 1.5 sck cycle
          && cnt <= 9' (39 + 23 * 16)    // sampling 0 to 23
          && cnt [3:0] == 4'd7;          // posedge sck

    wire value_done = (ws == lr) & (cnt == '1);


    //------------------------------------------------------------------------

    logic [23:0] shift;

    always_ff @ (posedge clk or posedge rst)
        if (rst)
        begin
            shift        <= '0;
            sample_valid <= '0;
            sample       <= '0;
        end
        else if (clk_en)
        begin
            sample_valid <= value_done;

            if (sample_bit)
                shift <= { shift [22:0], sd };
            else if (value_done)
            begin
                sample <= shift;
            end
        end

endmodule
