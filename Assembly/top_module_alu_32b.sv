// ALU type select: edit alu_cfg.svh (ALU_SIGNED / ALU_UNSIGNED), or pass +define+ALU_SIGNED / +define+ALU_UNSIGNED.
// Only the selected ALU is instantiated; the other one's files can stay in the project.
`include "alu_cfg.svh"

module top_module_alu_32b
(
	input 			[31:0]			vector_a, vector_b,
	input							clock, reset_active_low, enable,
	input 			[4:0]			op_code,
	output			logic			carry_out, divide_by_zero_fault, illegal_op_fault, zeroed_vector_result, completed_op,
	output 			[63:0]			vector_result
);

	// Status Register Breakout
	logic			[4:0]			status_register;

`ifdef ALU_SIGNED
	// Signed 32-Bit ALU (sequential adder/multiplier/divider). carry_out carries SIGNED OVERFLOW in this build.
	alu_32bit_signed				dut
`else
	// Unsigned 32-Bit ALU. carry_out is the unsigned carry/borrow.
	alu_32bit						dut
`endif
	(
		.vector_a					(vector_a),
		.vector_b					(vector_b),
		.op_code					(op_code),
		.clock						(clock),
		.reset_active_low			(reset_active_low),
		.enable						(enable),
		.status_reg					(status_register),
		.vector_result				(vector_result)
	);

	// Status Register Decoder
	assign carry_out 				= status_register[4];
	assign divide_by_zero_fault 	= status_register[3];
	assign illegal_op_fault 		= status_register[2];
	assign zeroed_vector_result 	= status_register[1];
	assign completed_op 			= status_register[0];

endmodule
