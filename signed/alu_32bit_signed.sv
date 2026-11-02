// 32-bit SIGNED ALU. Same ports, op codes and status-bit layout as alu_32bit (unsigned), so the top module can swap them.
//
// Timing: logic / compare / shift / NOP finish in 1 clock after the op is accepted. ADD, SUB, MULT, DIV and MOD run on the
// sequential units and take many clocks. The FSM issues `start` to the one unit, waits for that unit's `done`, and only
// then loads vector_result and raises completed_op (status_reg[0]). completed_op == 0 therefore means "busy or no op yet".
//   Clocks from enable going low to completed_op rising (first clock that sees enable low = 1; the unsigned ALU takes 4):
//     logic/compare/shift/NOP/faults : 3      MULT : 20      ADD/SUB : 36      DIV/MOD : 37 (3 for divide-by-zero)
//   An enable pulse that arrives while an op is running is ignored (the op in flight is not disturbed).
//
// Signed conventions:
//   - Every 32-bit result is sign-extended onto the 64-bit result bus. MULT returns the full 64-bit signed product.
//   - SLT/SGT/SLTE/SGTE are signed compares.  SLR is an ARITHMETIC right shift here (sign bit is replicated).
//   - DIV/MOD truncate toward zero, remainder takes the dividend's sign. divide-by-zero behaves like the unsigned ALU:
//     divide_by_zero is flagged, the op becomes a NOP and the previous result is kept.
//   - status_reg[4] (named carry_out in the top module) is SIGNED OVERFLOW here: ADD/SUB overflow, and -2^31 / -1 for DIV.
//   status_reg = {overflow, divide_by_zero, illegal_op, zero, complete}, flags are gated by complete like the unsigned ALU.
module alu_32bit_signed
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

	// Op codes: keep identical to alu_32bit (unsigned)
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

	typedef			enum			logic			[1:0]
	{
		S_IDLE,			// waiting for the one-shot
		S_ISSUE,		// operands latched; start a unit, or finish a one-clock op
		S_WAIT			// waiting for the started unit's done
	}	state_t;

	state_t											state;

					logic	signed	[31:0]			internal_vector_a, internal_vector_b;
					logic			[4:0]			internal_op_code;
					logic							one_shot_en;
					logic							illegal_op, divide_by_zero, overflow_out, zero_out, complete;

	input_one_shot	one_shot_enable(enable, clock, reset_active_low, one_shot_en);

	// ---------------- Sequential units ----------------
					logic							add_start, add_done, add_ovf;
					logic	signed	[31:0]			add_result;
					logic							mul_start, mul_done;
					logic	signed	[63:0]			mul_product;
					logic							div_start, div_done, div_ovf;
					logic	signed	[31:0]			div_quotient, div_remainder;

	wire			op_is_addsub	= (internal_op_code == ADD)  || (internal_op_code == SUB);
	wire			op_is_mult		= (internal_op_code == MULT);
	wire			op_is_divmod	= (internal_op_code == DIV)  || (internal_op_code == MOD);

	assign			add_start		= (state == S_ISSUE) && op_is_addsub;
	assign			mul_start		= (state == S_ISSUE) && op_is_mult;
	assign			div_start		= (state == S_ISSUE) && op_is_divmod;

	adder_subtractor_unit_signed	u_addsub
	(
		.clock					(clock),
		.reset_active_low		(reset_active_low),
		.start					(add_start),
		.sub					(internal_op_code == SUB),
		.a						(internal_vector_a),
		.b						(internal_vector_b),
		.busy					(),
		.done					(add_done),
		.result					(add_result),
		.overflow				(add_ovf)
	);

	multiplier_unit_signed			u_mult
	(
		.clock					(clock),
		.reset_active_low		(reset_active_low),
		.start					(mul_start),
		.vector_a				(internal_vector_a),
		.vector_b				(internal_vector_b),
		.busy					(),
		.done					(mul_done),
		.product				(mul_product)
	);

	divider_unit_signed				u_div
	(
		.clock					(clock),
		.reset_active_low		(reset_active_low),
		.start					(div_start),
		.vector_a				(internal_vector_a),
		.vector_b				(internal_vector_b),
		.busy					(),
		.done					(div_done),
		.quotient				(div_quotient),
		.remainder				(div_remainder),
		.div_by_zero			(),				// zero divisors are caught before the unit is started
		.overflow				(div_ovf)
	);

	// ---------------- One-clock operations ----------------
					logic	signed	[31:0]			bitwise_result;
					logic			[63:0]			simple_result;

	always_comb begin
		bitwise_result = '0;
		case (internal_op_code)
			NOTA	: bitwise_result =  ~internal_vector_a;
			NOTB	: bitwise_result =  ~internal_vector_b;
			AND		: bitwise_result =   (internal_vector_a & internal_vector_b);
			NAND	: bitwise_result =  ~(internal_vector_a & internal_vector_b);
			OR		: bitwise_result =   (internal_vector_a | internal_vector_b);
			NOR		: bitwise_result =  ~(internal_vector_a | internal_vector_b);
			XOR		: bitwise_result =   (internal_vector_a ^ internal_vector_b);
			XNOR	: bitwise_result =  ~(internal_vector_a ^ internal_vector_b);
			SLR		: bitwise_result =   (internal_vector_a >>> internal_vector_b[4:0]);	// arithmetic
			SLL		: bitwise_result =   (internal_vector_a <<  internal_vector_b[4:0]);
			default	: bitwise_result = '0;
		endcase

		simple_result = {{32{bitwise_result[31]}}, bitwise_result};			// sign-extend to the 64-bit bus
		case (internal_op_code)
			SLT		: simple_result = {63'b0, (internal_vector_a <  internal_vector_b)};
			SGT		: simple_result = {63'b0, (internal_vector_a >  internal_vector_b)};
			SLTE	: simple_result = {63'b0, (internal_vector_a <= internal_vector_b)};
			SGTE	: simple_result = {63'b0, (internal_vector_a >= internal_vector_b)};
			SEQU	: simple_result = {63'b0, (internal_vector_a == internal_vector_b)};
			SNEQ	: simple_result = {63'b0, (internal_vector_a != internal_vector_b)};
			NOP		: simple_result = vector_result;						// hold previous result
			default	: ;
		endcase
	end

	// ---------------- Control FSM ----------------
	always_ff @(posedge clock, negedge reset_active_low) begin
		if (!reset_active_low) begin
			state				<= S_IDLE;
			internal_vector_a	<= '0;
			internal_vector_b	<= '0;
			internal_op_code	<= NOP;
			illegal_op			<= 1'b0;
			divide_by_zero		<= 1'b0;
			overflow_out		<= 1'b0;
			zero_out			<= 1'b0;
			complete			<= 1'b0;
			vector_result		<= '0;
		end
		else begin
			case (state)
				S_IDLE: begin
					if (one_shot_en) begin
						complete			<= 1'b0;
						internal_vector_a	<= vector_a;
						internal_vector_b	<= vector_b;
						if (op_code > 5'd21) begin							// illegal op
							internal_op_code	<= NOP;
							illegal_op			<= 1'b1;
							divide_by_zero		<= 1'b0;
						end
						else if (((op_code == DIV) || (op_code == MOD)) && (vector_b == 32'b0)) begin
							internal_op_code	<= NOP;
							illegal_op			<= 1'b0;
							divide_by_zero		<= 1'b1;
						end
						else begin
							internal_op_code	<= op_code;
							illegal_op			<= 1'b0;
							divide_by_zero		<= 1'b0;
						end
						state				<= S_ISSUE;
					end
				end

				S_ISSUE: begin
					if (op_is_addsub || op_is_mult || op_is_divmod) begin	// unit sees start this cycle
						state			<= S_WAIT;
					end
					else begin												// finishes in one clock
						vector_result	<= simple_result;
						zero_out		<= (simple_result == 64'b0);
						overflow_out	<= 1'b0;
						complete		<= 1'b1;
						state			<= S_IDLE;
					end
				end

				S_WAIT: begin
					if (add_done) begin
						vector_result	<= {{32{add_result[31]}}, add_result};
						zero_out		<= (add_result == 32'sd0);
						overflow_out	<= add_ovf;
						complete		<= 1'b1;
						state			<= S_IDLE;
					end
					else if (mul_done) begin
						vector_result	<= mul_product;
						zero_out		<= (mul_product == 64'sd0);
						overflow_out	<= 1'b0;
						complete		<= 1'b1;
						state			<= S_IDLE;
					end
					else if (div_done) begin
						if (internal_op_code == DIV) begin
							vector_result	<= {{32{div_quotient[31]}}, div_quotient};
							zero_out		<= (div_quotient == 32'sd0);
							overflow_out	<= div_ovf;						// -2^31 / -1
						end
						else begin
							vector_result	<= {{32{div_remainder[31]}}, div_remainder};
							zero_out		<= (div_remainder == 32'sd0);
							overflow_out	<= 1'b0;
						end
						complete		<= 1'b1;
						state			<= S_IDLE;
					end
				end

				default: state <= S_IDLE;
			endcase
		end
	end

	assign status_reg = {overflow_out && complete, divide_by_zero && complete, illegal_op && complete, zero_out && complete, complete};

endmodule
