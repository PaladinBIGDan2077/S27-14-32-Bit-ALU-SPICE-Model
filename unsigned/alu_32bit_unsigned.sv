module alu_32bit
(
	input 							[31:0]			vector_a,
	input 							[31:0]			vector_b,
	input 							[4:0]			op_code,
	input											clock,
	input											reset_active_low,
	input											enable,
	output			logic			[4:0]			status_reg,
	output			logic			[63:0]			vector_result
);

					logic			[31:0]			internal_vector_a, internal_vector_b;
					logic			[64:0]			internal_vector_result;
					logic			[4:0]			internal_op_code;
					logic							activate, complete, zero_out, carry_out, one_shot_en, trigger_output, illegal_op, divide_by_zero;
					
	input_one_shot	one_shot_enable(enable, clock, reset_active_low, one_shot_en);
					
	typedef			enum			logic			[4:0]
	{
		ADD,
		SUB,
		NOTA,
		NOTB,
		AND,
		NAND,
		OR,
		NOR,
		XOR,
		XNOR,
		SLT,
		SGT,
		SLTE,
		SGTE,
		SEQU,
		SNEQ,
		SLR,
		SLL,
		NOP,
		MULT,
		DIV,
		MOD
	}	operation_codes;
	
	always_ff @(posedge clock, negedge reset_active_low) begin
		if (!reset_active_low) begin
			internal_op_code <= 5'b0;
			illegal_op <= 1'b0;
			divide_by_zero <= 1'b0;
			internal_vector_a <= 32'h00000000;
			internal_vector_b <= 32'h00000000;
		end
		else begin
			if (one_shot_en) begin
				if (op_code <= 5'd21) begin
					internal_vector_a <= vector_a;
					if (op_code == DIV) begin
						if (vector_b == 32'b0) begin
							internal_op_code <= NOP;
							divide_by_zero <= 1'b1;
							illegal_op <= 1'b0;
						end
						else begin
							internal_vector_b <= vector_b;
							internal_op_code <= op_code;
							divide_by_zero <= 1'b0;
							illegal_op <= 1'b0;
						end
					end		
					else if (op_code == MOD) begin
						if (vector_b == 32'b0) begin
							internal_op_code <= NOP;
							divide_by_zero <= 1'b1;
							illegal_op <= 1'b0;
						end
						else begin
							internal_vector_b <= vector_b;
							internal_op_code <= op_code;
							divide_by_zero <= 1'b0;
							illegal_op <= 1'b0;
						end
					end
					else begin
						internal_vector_b <= vector_b;
						internal_op_code <= op_code;
						divide_by_zero <= 1'b0;
						illegal_op <= 1'b0;
					end
				end
				if (op_code >= 5'd22) begin
					internal_op_code <= NOP;
					illegal_op <= 1'b1;
					divide_by_zero <= 1'b0;
				end
			end
		end
	end
			
	always_ff @(posedge clock, negedge reset_active_low) begin
		if (!reset_active_low) begin
			activate					    		<= 1'b0;
			complete					    		<= 1'b0;
			carry_out					    		<= 1'b0;
			zero_out					    		<= 1'b0;
			trigger_output					    	<= 1'b0;
			vector_result					    	<= 64'h0000000000000000;
			internal_vector_result					<= 65'h00000000000000000;
		end
		else begin
			if (trigger_output) begin
				vector_result					    <= internal_vector_result[63:0];
				case (internal_op_code)
					ADD     : carry_out <= internal_vector_result[32];
					SUB     : carry_out <= (internal_vector_b > internal_vector_a);
					default : carry_out <= 1'b0;
				endcase
				zero_out 						    <= (internal_vector_result[63:0] == 64'b0);
				complete 						    <= 1'b1;
				activate						   	<= 1'b0;
			end
			trigger_output 			   		    	<= 1'b0;
			if (one_shot_en) begin
				activate						    <= 1'b1;
				complete 						    <= 1'b0;
			end
			if (activate) begin
				case(internal_op_code)
					ADD    :	internal_vector_result 	<= 	(internal_vector_a + internal_vector_b);
					SUB    : 	internal_vector_result 	<= 	{33'b0, (internal_vector_a - internal_vector_b)};
					NOTA   :	internal_vector_result 	<= 	{33'b0, ~internal_vector_a};
					NOTB   :	internal_vector_result 	<= 	{33'b0, ~internal_vector_b};
					AND    :	internal_vector_result 	<= 	{33'b0,  (internal_vector_a & internal_vector_b)};
					NAND   :	internal_vector_result 	<= 	{33'b0, ~(internal_vector_a & internal_vector_b)};
					OR     :	internal_vector_result 	<= 	{33'b0,  (internal_vector_a | internal_vector_b)};
					NOR    :	internal_vector_result 	<= 	{33'b0, ~(internal_vector_a | internal_vector_b)};
					XOR    :	internal_vector_result 	<= 	{33'b0,  (internal_vector_a ^ internal_vector_b)};
					XNOR   :	internal_vector_result 	<= 	{33'b0, ~(internal_vector_a ^ internal_vector_b)};
					SLT    :	internal_vector_result 	<= 	{64'b0, (internal_vector_a <  internal_vector_b)};
					SGT    :	internal_vector_result 	<= 	{64'b0, (internal_vector_a >  internal_vector_b)};
					SLTE   :	internal_vector_result 	<= 	{64'b0, (internal_vector_a <= internal_vector_b)};
					SGTE   :	internal_vector_result 	<= 	{64'b0, (internal_vector_a >= internal_vector_b)};
					SEQU   :	internal_vector_result 	<= 	{64'b0, (internal_vector_a == internal_vector_b)};
					SNEQ   :	internal_vector_result 	<= 	{64'b0, (internal_vector_a != internal_vector_b)};
					SLR    :	internal_vector_result 	<= 	(internal_vector_a >> internal_vector_b[4:0]);
					SLL    :	internal_vector_result 	<= 	({33'b0, (internal_vector_a << internal_vector_b[4:0])});
					NOP    :	internal_vector_result 	<= 	(internal_vector_result);
					MULT   :	internal_vector_result 	<= 	(internal_vector_a * internal_vector_b);
					DIV    :	internal_vector_result 	<= 	(internal_vector_a / internal_vector_b);
					MOD    :	internal_vector_result 	<= 	(internal_vector_a % internal_vector_b);
					default:	internal_vector_result	<= 	65'b0;
				endcase
				trigger_output 			   		   		<= 1'b1;
				activate						   		<= 1'b0;
			end
		end
	end

	assign status_reg = ({carry_out && complete, divide_by_zero && complete, illegal_op && complete, zero_out && complete, complete});

endmodule
	
module input_one_shot
(
	input 					momentary_in,
	input 					clock,
	input 					reset_active_low,
	output		logic		one_shot_out
);
	
	logic [1:0]	current_state, next_state;
	
	always_ff @(posedge clock, negedge reset_active_low) begin
		if (!reset_active_low) begin
			current_state <= 2'b00;
		end
		else begin
			current_state <= next_state;
		end
	end
	
	always_comb begin
		case(current_state)
			2'b00:	next_state =  momentary_in ? 2'b01 : 2'b00;
			2'b01:	next_state = !momentary_in ? 2'b10 : 2'b01;
			2'b10: 	next_state = 2'b00;
			default:next_state = 2'b00;
		endcase
	end

	always_comb begin
		if (!reset_active_low) begin
			one_shot_out = 1'b0;
		end
		else begin
			case(current_state)
				2'b00:	one_shot_out = 1'b0;
				2'b01:	one_shot_out = 1'b0;
				2'b10: 	one_shot_out = 1'b1;
				default:one_shot_out = 1'b0;
			endcase
		end
	end
	
endmodule