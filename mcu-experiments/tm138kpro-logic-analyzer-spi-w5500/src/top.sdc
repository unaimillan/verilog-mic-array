//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11 (64-bit) 
//Created Time: 2026-05-03 21:50:21
create_clock -name sys_clk -period 20 -waveform {0 10} [get_ports {sys_clk_50mhz}]
