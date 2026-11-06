// Program-driven, self-checking testbench for top_module_alu_32b (signed or unsigned build, picked in alu_cfg.svh).
//
// Like a CPU testbench with several programs: each program <name> is a pair of $readmemh files made by asm_alu.py
//   <name>.hex                    instructions   OO AAAAAAAA BBBBBBBB   (opcode, vector_a, vector_b)
//   <name>_expected_signed.hex    expected results for the SIGNED ALU     FF RRRRRRRRRRRRRRRR   (flags, 64-bit result)
//   <name>_expected_unsigned.hex  expected results for the UNSIGNED ALU
// By default every program in PROGRAMS below runs back to back (the ALU is reset before each one). Plusargs:
//   +PROG=<name>   run only that program        +DIR=<path/>   folder holding the .hex files (default: working dir)
//   +VERBOSE       print every vector
// The actual results are written to actual_<name>_<signed|unsigned>.hex in the expected-file format, so they can be diffed.
// Flags byte = {4'b0, carry_out, divide_by_zero_fault, illegal_op_fault, zeroed_vector_result}.
//
// Each vector: drive operands, pulse enable (the ALU starts when enable falls), wait for completed_op to RISE (the signed
// ALU needs many clocks for ADD/SUB/MULT/DIV/MOD), then compare result + flags with the expected file.
`include "alu_cfg.svh"
`timescale 1ns/1ps
module tb_alu_32b();

	localparam	int		TIMEOUT   = 200;		// clocks to wait for completed_op before declaring a hang
	localparam	int		MAXV      = 4096;		// program memory depth
	localparam	int		NPROGRAMS = 3;

`ifdef ALU_SIGNED
	localparam	string	MODE = "signed";
`else
	localparam	string	MODE = "unsigned";
`endif

	// Add new programs here (and bump NPROGRAMS): python3 asm_alu.py myprog.asm  ->  myprog*.hex
	function automatic string program_name(input int i);
		case (i)
			0: return "alu_tests";			// 25 vectors for every op, one test (section) per op, plus illegal op codes
			1: return "mixed_ops";			// 120 random instructions back to back, random order
			2: return "fault_flags";		// divide-by-zero / illegal / NOP "keep the previous result" cases
			default: return "";
		endcase
	endfunction

	// I/O
	logic 			[31:0]			vector_a, vector_b;
	logic 			[63:0]			vector_result;
	logic							clock = 1'b0, reset_active_low, enable;
	logic 			[4:0]			op_code;
	logic							carry_out, divide_by_zero_fault, illegal_op_fault, zeroed_vector_result, completed_op;

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

	// Program / expected memories (reloaded for each program)
	logic	[71:0]	prog		[0:MAXV-1];
	logic	[71:0]	expect_mem	[0:MAXV-1];

	string			dir = "", only_prog = "";
	int				verbose = 0;
	int				errors = 0, total_vectors = 0, programs_run = 0;

	function automatic string opname(input int op);
		case (op)
			0: return "ADD";   1: return "SUB";   2: return "NOTA";  3: return "NOTB";  4: return "AND";   5: return "NAND";
			6: return "OR";    7: return "NOR";   8: return "XOR";   9: return "XNOR";  10: return "SLT";  11: return "SGT";
			12: return "SLTE"; 13: return "SGTE"; 14: return "SEQU"; 15: return "SNEQ"; 16: return "SLR";  17: return "SLL";
			18: return "NOP";  19: return "MULT"; 20: return "DIV";  21: return "MOD";  default: return "ILLEGAL";
		endcase
	endfunction

	// ---------------- Drive / wait ----------------
	task automatic apply_reset();
		begin
			enable = 1'b0; vector_a = '0; vector_b = '0; op_code = 5'd18; reset_active_low = 1'b0;
			repeat (3) @(negedge clock);
			reset_active_low = 1'b1;
			repeat (2) @(negedge clock);
		end
	endtask

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

	// ---------------- Load one program, run it, check it ----------------
	task automatic run_program(input string name);
		string			prog_file, exp_file, act_file;
		logic	[71:0]	pw, ew;
		logic	[4:0]	op;
		logic	[31:0]	a, b;
		logic	[3:0]	got_flags;
		logic	[63:0]	got_res;
		int				nvec, cyc, bucket, fd, prog_errors;
		int				t_count [0:22];
		int				t_pass  [0:22];
		int				lat_min [0:22];
		int				lat_max [0:22];
		bit				ok;
		begin
			prog_file = {dir, name, ".hex"};
			exp_file  = {dir, name, "_expected_", MODE, ".hex"};
			act_file  = {"actual_", name, "_", MODE, ".hex"};

			for (int i = 0; i < MAXV; i++) begin prog[i] = 'x; expect_mem[i] = 'x; end
			$readmemh(prog_file, prog);
			$readmemh(exp_file,  expect_mem);
			nvec = 0;
			while (nvec < MAXV && ^prog[nvec] !== 1'bx) nvec++;
			if (nvec == 0) begin
				errors++; $display("ERROR: no instructions loaded from %s (is it in the simulator's working directory? use +DIR=)", prog_file);
			end
			else if (^expect_mem[nvec-1] === 1'bx) begin
				errors++; $display("ERROR: %s has fewer entries than %s (%0d)", exp_file, prog_file, nvec);
			end
			else begin
				$display("");
				$display("== program %s: %0d instructions (%s), expected results from %s", name, nvec, prog_file, exp_file);
				for (int i = 0; i <= 22; i++) begin t_count[i] = 0; t_pass[i] = 0; lat_min[i] = 0; lat_max[i] = 0; end
				prog_errors = 0;
				fd = $fopen(act_file, "w");
				apply_reset();										// expected files assume the ALU starts from reset

				for (int i = 0; i < nvec; i++) begin
					pw = prog[i]; ew = expect_mem[i];
					op = pw[68:64]; a = pw[63:32]; b = pw[31:0];
					bucket = (op < 22) ? int'(op) : 22;

					start_pulse(op, a, b);
					wait_done(cyc);
					got_flags = {carry_out, divide_by_zero_fault, illegal_op_fault, zeroed_vector_result};
					got_res   = vector_result;
					$fdisplay(fd, "%02h%016h // %04d %s", {4'b0, got_flags}, got_res, i, opname(bucket));

					t_count[bucket]++;
					ok = (cyc < TIMEOUT) && (got_res === ew[63:0]) && (got_flags === ew[67:64]);
					if (cyc < TIMEOUT) begin
						if (lat_max[bucket] == 0 || cyc < lat_min[bucket]) lat_min[bucket] = cyc;
						if (cyc > lat_max[bucket]) lat_max[bucket] = cyc;
					end
					if (ok) t_pass[bucket]++;
					else begin
						prog_errors++;
						if (prog_errors <= 15) begin
							if (cyc >= TIMEOUT) $display("HANG  %s #%0d %s a=%h b=%h : completed_op never rose", name, i, opname(bucket), a, b);
							else $display("FAIL  %s #%0d %s a=%h b=%h : got res=%h flags=%b | expected res=%h flags=%b  (flags = carry/ovf,dbz,illegal,zero)",
									name, i, opname(bucket), a, b, got_res, got_flags, ew[63:0], ew[67:64]);
						end
					end
					if (verbose)
						$display("%s #%04d %-7s a=%h b=%h res=%h flags=%b exp=%h/%b clks=%0d", ok ? "ok  " : "FAIL", i, opname(bucket),
								 a, b, got_res, got_flags, ew[63:0], ew[67:64], cyc);
				end
				$fclose(fd);

				$display("  test      pass/total   clocks min/max (enable low -> completed_op)");
				for (int t = 0; t <= 22; t++)
					if (t_count[t] != 0)
						$display("  %-8s  %3d/%-3d      %0d / %0d", opname(t), t_pass[t], t_count[t], lat_min[t], lat_max[t]);
				$display("  program %s (%s ALU): %s  (%0d mismatches / %0d vectors)", name, MODE, prog_errors == 0 ? "PASS" : "FAILED", prog_errors, nvec);
				errors += prog_errors; total_vectors += nvec; programs_run++;
			end
		end
	endtask

	initial begin
		int cyc;
		if ($test$plusargs("VERBOSE")) verbose = 1;
		void'($value$plusargs("DIR=%s", dir));
		void'($value$plusargs("PROG=%s", only_prog));

		if (only_prog != "") run_program(only_prog);
		else for (int p = 0; p < NPROGRAMS; p++) run_program(program_name(p));

`ifdef ALU_SIGNED
		// A second enable pulse while an op is running must be ignored (the signed ALU is multi-cycle).
		begin
			logic [63:0] prod;
			prod = 64'(-64'sd21);											// 7 * -3
			apply_reset();
			start_pulse(5'd19, 32'd7, 32'hFFFFFFFD);
			repeat (6) @(negedge clock);
			start_pulse(5'd0, 32'd1, 32'd2);								// arrives mid-multiply
			wait_done(cyc);
			repeat (10) @(posedge clock);
			#1;
			if (cyc >= TIMEOUT || vector_result !== prod || !completed_op) begin
				errors++; $display("FAIL  busy-ignore: res=%h expected %h cyc=%0d", vector_result, prod, cyc);
			end
			else $display("\nok    enable pulse during a running MULT was ignored");
		end
`endif

		$display("");
		if (errors == 0 && programs_run != 0) $display("PASS: %0d programs, %0d vectors, all matched the expected files (%s ALU)", programs_run, total_vectors, MODE);
		else $display("FAILED: %0d errors (%0d programs run, %0d vectors) (%s ALU)", errors, programs_run, total_vectors, MODE);
		$stop;
	end

endmodule
