
module logic_analyzer (
	acq_data_in,
	acq_trigger_in,
	acq_clk,
	storage_enable);	

	input	[23:0]	acq_data_in;
	input	[0:0]	acq_trigger_in;
	input		acq_clk;
	input		storage_enable;
endmodule
