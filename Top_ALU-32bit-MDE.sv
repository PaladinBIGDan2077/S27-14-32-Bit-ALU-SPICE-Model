module top_alu_32bit_mde
(
	input														clock_50,
	input														reset_active_low,
	input														switch,
	input														mode_sel,
	input														advance_in,
	inout			logic										FPGA_I2C_SCLK,
	inout			logic										FPGA_I2C_SDAT,
    output          logic       			[6:0]       		display_0,
    output          logic       			[6:0]       		display_1,
    output          logic       			[6:0]       		display_2,
    output          logic       			[6:0]       		display_3,
	output			logic					[5:0]				addr
);

endmodule