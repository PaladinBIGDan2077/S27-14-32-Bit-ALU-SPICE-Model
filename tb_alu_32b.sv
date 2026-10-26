`timescale 1ns/1ns
module tb_alu_32b();
	// I/O
	logic 			[31:0]			vector_a_unsigned, vector_b_unsigned;
	logic 			[5:0]			status_register;
	logic 			[63:0]			vector_result_unsigned;
	logic							clock, reset_active_low, enable;
	logic 			[4:0]			op_code;
	// Status Register Breakout
	logic							carry_out, divide_by_zero_fault, illegal_op_fault, zeroed_vector_result, completed_op;			
	
	// Unsigned 32-Bit ALU DUT
	top_module_alu_32b 				dut
	(	
		.vector_a					(vector_a_unsigned),
		.vector_b					(vector_b_unsigned),
		.op_code					(op_code),
		.clock						(clock),
		.reset_active_low			(reset_active_low),
		.enable						(enable),
		.carry_out					(carry_out),
		.divide_by_zero_fault		(divide_by_zero_fault),
		.illegal_op_fault			(illegal_op_fault),
		.zeroed_vector_result		(zeroed_vector_result),
		.completed_op				(completed_op),
		.vector_result				(vector_result_unsigned)
	);
	
	forever begin
		#25;
		clock = !clock;
	end
	
endmodule