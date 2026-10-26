module top_module_alu_32b
(
	input	 		[31:0]			vector_a_unsigned, vector_b_unsigned;
	input							clock, reset_active_low, enable;
	input 			[4:0]			op_code;
	output			logic			carry_out, divide_by_zero_fault, illegal_op_fault, zeroed_vector_result, completed_op;
	output 			[63:0]			vector_result_unsigned;
);

	// Status Register Breakout
	logic							status_register;			
	
	// Unsigned 32-Bit ALU DUT
	alu_32bit_unsigned 				dut
	(	
		.vector_a					(vector_a_unsigned),
		.vector_b					(vector_b_unsigned),
		.op_code					(op_code),
		.clock						(clock),
		.reset_active_low			(reset_active_low),
		.enable						(enable),
		.status_reg					(status_register),
		.vector_result				(vector_result_unsigned)
	);
	
	// Status Register Decoder
	assign carry_out 				= status_register[4];
	assign divide_by_zero_fault 	= status_register[3];
	assign illegal_op_fault 		= status_register[2];
	assign zeroed_vector_result 	= status_register[1];
	assign completed_op 			= status_register[0];

endmodule