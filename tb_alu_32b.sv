`timescale 1ns/1ns
`include "alu_cfg.svh"
module tb_alu_32b();

	localparam	int		TIMEOUT = 200;			// clocks to wait for completed_op before declaring a hang

	// I/O
	logic 			[31:0]			vector_a, vector_b;
	logic 			[63:0]			vector_result;
	logic							clock = 1'b0, reset_active_low, enable;
	logic 			[4:0]			op_code;
	logic							carry_out, divide_by_zero_fault, illegal_op_fault, zeroed_vector_result, completed_op;

	// Op codes (same order as the ALUs)
	localparam	[4:0]	ADD=0, SUB=1, NOTA=2, NOTB=3, AND=4, NAND=5, OR=6, NOR=7, XOR=8, XNOR=9, SLT=10, SGT=11,
						SLTE=12, SGTE=13, SEQU=14, SNEQ=15, SLR=16, SLL=17, NOP=18, MULT=19, DIV=20, MOD=21;

	top_module_alu_32b 				dut
	(
		.vector_a					(vector_a),
		.vector_b					(vector_b),
		.op_code					(op_code),
		.clock						(clock),
		.reset_active_low			(reset_active_low),
		.enable						(enable),
		.carry_out					(carry_out),
		.divide_by_zero_fault		(divide_by_zero_fault),
		.illegal_op_fault			(illegal_op_fault),
		.zeroed_vector_result		(zeroed_vector_result),
		.completed_op				(completed_op),
		.vector_result				(vector_result)
	);

	always #12.5 clock = !clock;				// 25 ns period, matches timingfile.sdc

	int				errors = 0, tests = 0;
	int				lat_min [0:31];
	int				lat_max [0:31];
	logic	[63:0]	exp_last = 64'b0;			// reference copy of the last result (NOP / faults keep it)

	// ---------------- Reference model ----------------
	task automatic model(input [4:0] op, input [31:0] a, input [31:0] b,
						 output logic [63:0] res, output logic c, output logic dbz, output logic ill);
`ifdef ALU_SIGNED
		logic signed [31:0] sa, sb, r32;
		logic signed [63:0] w;
`else
		logic [64:0] t;
`endif
		begin
			res = exp_last; c = 1'b0; dbz = 1'b0; ill = 1'b0;
			if (op > 5'd21)								ill = 1'b1;
			else if ((op == DIV || op == MOD) && b == 0)	dbz = 1'b1;
			else begin
`ifdef ALU_SIGNED
				sa = a; sb = b; r32 = '0;
				case (op)
					ADD  : begin w = 64'(sa) + 64'(sb); r32 = w[31:0]; res = {{32{r32[31]}}, r32}; c = (w != 64'(r32)); end
					SUB  : begin w = 64'(sa) - 64'(sb); r32 = w[31:0]; res = {{32{r32[31]}}, r32}; c = (w != 64'(r32)); end
					NOTA : begin r32 = ~sa;           res = {{32{r32[31]}}, r32}; end
					NOTB : begin r32 = ~sb;           res = {{32{r32[31]}}, r32}; end
					AND  : begin r32 = sa & sb;       res = {{32{r32[31]}}, r32}; end
					NAND : begin r32 = ~(sa & sb);    res = {{32{r32[31]}}, r32}; end
					OR   : begin r32 = sa | sb;       res = {{32{r32[31]}}, r32}; end
					NOR  : begin r32 = ~(sa | sb);    res = {{32{r32[31]}}, r32}; end
					XOR  : begin r32 = sa ^ sb;       res = {{32{r32[31]}}, r32}; end
					XNOR : begin r32 = ~(sa ^ sb);    res = {{32{r32[31]}}, r32}; end
					SLT  : res = {63'b0, (sa <  sb)};
					SGT  : res = {63'b0, (sa >  sb)};
					SLTE : res = {63'b0, (sa <= sb)};
					SGTE : res = {63'b0, (sa >= sb)};
					SEQU : res = {63'b0, (sa == sb)};
					SNEQ : res = {63'b0, (sa != sb)};
					SLR  : begin r32 = sa >>> b[4:0]; res = {{32{r32[31]}}, r32}; end
					SLL  : begin r32 = sa <<  b[4:0]; res = {{32{r32[31]}}, r32}; end
					NOP  : res = exp_last;
					MULT : res = 64'(sa) * 64'(sb);
					DIV  : begin w = 64'(sa) / 64'(sb); r32 = w[31:0]; res = {{32{r32[31]}}, r32};
								 c = (sa == 32'sh80000000) && (sb == -32'sd1); end
					MOD  : begin w = 64'(sa) % 64'(sb); r32 = w[31:0]; res = {{32{r32[31]}}, r32}; end
					default : ;
				endcase
`else
				case (op)
					ADD  : begin t = a + b; res = t[63:0]; c = t[32]; end
					SUB  : begin res = {32'b0, a - b}; c = (b > a); end
					NOTA : res = {32'b0, ~a};
					NOTB : res = {32'b0, ~b};
					AND  : res = {32'b0,  (a & b)};
					NAND : res = {32'b0, ~(a & b)};
					OR   : res = {32'b0,  (a | b)};
					NOR  : res = {32'b0, ~(a | b)};
					XOR  : res = {32'b0,  (a ^ b)};
					XNOR : res = {32'b0, ~(a ^ b)};
					SLT  : res = {63'b0, (a <  b)};
					SGT  : res = {63'b0, (a >  b)};
					SLTE : res = {63'b0, (a <= b)};
					SGTE : res = {63'b0, (a >= b)};
					SEQU : res = {63'b0, (a == b)};
					SNEQ : res = {63'b0, (a != b)};
					SLR  : res = {32'b0, (a >> b[4:0])};
					SLL  : res = {32'b0, (a << b[4:0])};
					NOP  : res = exp_last;
					MULT : res = 64'(a) * 64'(b);
					DIV  : res = {32'b0, a / b};
					MOD  : res = {32'b0, a % b};
					default : ;
				endcase
`endif
			end
		end
	endtask

	// ---------------- Drive / wait / check ----------------
	task automatic start_pulse(input [4:0] op, input [31:0] a, input [31:0] b);
		begin
			vector_a = a; vector_b = b; op_code = op;
			@(negedge clock); enable = 1'b1;
			@(negedge clock);
			@(negedge clock); enable = 1'b0;
		end
	endtask

	// Count clocks from enable going low until completed_op rises. cyc == TIMEOUT means it never did.
	task automatic wait_done(output int cyc);
		logic prev, got;
		begin
			prev = completed_op; cyc = 0; got = 1'b0;
			while (!got && cyc < TIMEOUT) begin
				@(posedge clock); #1;
				cyc++;
				if (completed_op && !prev) got = 1'b1;
				prev = completed_op;
			end
		end
	endtask

	task automatic run_op(input [4:0] op, input [31:0] a, input [31:0] b);
		logic [63:0] er; logic ec, edbz, eill;
		int cyc;
		begin
			model(op, a, b, er, ec, edbz, eill);
			start_pulse(op, a, b);
			wait_done(cyc);
			tests++;
			if (cyc >= TIMEOUT) begin
				errors++; $display("HANG  op=%0d a=%h b=%h : completed_op never rose", op, a, b);
			end
			else begin
				if (cyc < lat_min[op < 22 ? op : 22] || lat_min[op < 22 ? op : 22] == 0) lat_min[op < 22 ? op : 22] = cyc;
				if (cyc > lat_max[op < 22 ? op : 22]) lat_max[op < 22 ? op : 22] = cyc;
				if (vector_result !== er || carry_out !== ec || divide_by_zero_fault !== edbz ||
					illegal_op_fault !== eill || zeroed_vector_result !== (er == 64'b0)) begin
					errors++;
					if (errors <= 20)
						$display("FAIL  op=%0d a=%h b=%h : got res=%h c=%b dbz=%b ill=%b z=%b | exp res=%h c=%b dbz=%b ill=%b z=%b",
							op, a, b, vector_result, carry_out, divide_by_zero_fault, illegal_op_fault, zeroed_vector_result,
							er, ec, edbz, eill, (er == 64'b0));
				end
			end
			exp_last = er;
		end
	endtask

	function automatic string opname(input int op);
		case (op)
			0: return "ADD";
			1: return "SUB";
			2: return "NOTA";
			3: return "NOTB";
			4: return "AND";
			5: return "NAND";
			6: return "OR";
			7: return "NOR";
			8: return "XOR";
			9: return "XNOR";
			10: return "SLT";
			11: return "SGT";
			12: return "SLTE";
			13: return "SGTE";
			14: return "SEQU";
			15: return "SNEQ";
			16: return "SLR";
			17: return "SLL";
			18: return "NOP";
			19: return "MULT";
			20: return "DIV";
			21: return "MOD";
			default: return "ILLEGAL";
		endcase
	endfunction

	logic [31:0] corner [0:9];
	logic [31:0] ra, rb;

	initial begin
		for (int i = 0; i < 32; i++) begin lat_min[i] = 0; lat_max[i] = 0; end
		corner[0] = 32'h00000000; corner[1] = 32'h00000001; corner[2] = 32'hFFFFFFFF; corner[3] = 32'h7FFFFFFF;
		corner[4] = 32'h80000000; corner[5] = 32'h80000001; corner[6] = 32'h40000000; corner[7] = 32'hC0000000;
		corner[8] = 32'h00000005; corner[9] = 32'hFFFFFFF9;		// 5 and -7

		enable = 1'b0; vector_a = '0; vector_b = '0; op_code = NOP; reset_active_low = 1'b0;
		repeat (3) @(negedge clock);
		reset_active_low = 1'b1;
		repeat (2) @(negedge clock);

		// 1) corner x corner for every legal op
		for (int op = 0; op < 22; op++)
			for (int i = 0; i < 10; i++)
				for (int j = 0; j < 10; j++)
					run_op(op[4:0], corner[i], corner[j]);

		// 2) random operands, with a mix of magnitudes
		for (int op = 0; op < 22; op++)
			for (int k = 0; k < 150; k++) begin
				ra = $urandom; rb = $urandom;
				case (k % 4)
					1: rb = rb >> ($urandom % 32);
					2: ra = ra >> ($urandom % 32);
					3: begin ra = ra >> ($urandom % 32); rb = rb >> ($urandom % 32); end
					default: ;
				endcase
				run_op(op[4:0], ra, rb);
			end

		// 3) divide by zero, illegal ops, NOP hold
		for (int k = 0; k < 6; k++) begin
			run_op(ADD, $urandom, $urandom);			// leaves a known previous result
			run_op(DIV, $urandom, 32'h0);
			run_op(MOD, $urandom, 32'h0);
		end
		for (int op = 22; op < 32; op++) begin
			run_op(ADD, $urandom, $urandom);
			run_op(op[4:0], $urandom, $urandom);
		end
		run_op(ADD, 32'd1234, 32'd4321); run_op(NOP, 32'd1, 32'd2); run_op(NOP, 32'd3, 32'd4);

`ifdef ALU_SIGNED
		// 4) signed build: an enable pulse while an op is running must be ignored
		begin
			int cyc;
			logic [63:0] er; logic ec, edbz, eill;
			model(MULT, 32'd7, 32'hFFFFFFFD, er, ec, edbz, eill);		// 7 * -3
			start_pulse(MULT, 32'd7, 32'hFFFFFFFD);
			repeat (6) @(negedge clock);
			start_pulse(ADD, 32'd1, 32'd2);								// arrives mid-multiply
			wait_done(cyc);
			tests++;
			if (vector_result !== er || cyc >= TIMEOUT) begin errors++; $display("FAIL  busy-ignore: res=%h exp=%h cyc=%0d", vector_result, er, cyc); end
			exp_last = er;
			repeat (10) @(posedge clock);
			#1;
			if (!completed_op || vector_result !== er) begin errors++; $display("FAIL  busy-ignore: ignored op was queued"); end
		end
`endif

		// Report
		$display("---- clocks from enable low to completed_op (min/max) ----");
		for (int op = 0; op < 23; op++)
			if (lat_max[op] != 0) $display("  %-8s %0d / %0d", opname(op), lat_min[op], lat_max[op]);
`ifdef ALU_SIGNED
		$display("---- build: SIGNED ALU ----");
`else
		$display("---- build: UNSIGNED ALU ----");
`endif
		if (errors == 0) $display("PASS: %0d tests", tests);
		else			 $display("FAILED: %0d errors / %0d tests", errors, tests);
		$finish;
	end

endmodule
