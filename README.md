# verilog-mic-array

SystemVerilog implementation of multi channel microphone module that accumulates sound from 2-10 microphones and merges into single data stream.

The continues stream of sound samples are captured from 4 to 8 microphones INMP441 connected via I2S and then send to the computer using the Wiznet W5500.
