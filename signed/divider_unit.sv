module divider_unit_signed
(
    input			logic											clock,
    input			logic               							reset_active_low,
    input			logic               							start,
    input			logic 			signed 			[31:0] 			vector_a,
    input			logic 			signed 			[31:0] 			vector_b,
    output			logic											busy,
    output 			logic											done,
    output 			logic 			signed 			[31:0] 			quotient,
    output 			logic 			signed 			[31:0] 			remainder,
    output 			logic											div_by_zero,
    output 			logic											overflow
);
    typedef 		enum 			logic 			[1:0] 
	{
		S_IDLE, 
		S_RUN, 
		S_FIX
	} 				state_t;
    
	state_t 		state;

					logic 							[31:0] 			D;			//Divider
					logic 							[31:0] 			Q;			//Quotient
					logic 							[32:0] 			R;			//Remainder
					logic 							[4:0]  			count;
					logic											neg_q;
					logic											neg_r;
					logic											dbz;
					logic 			signed 			[31:0] 			dividend_q;	// og dividend, divide-by-zero result

    // One restoring step
					logic 							[32:0] 			R_sh;
					logic 							[33:0] 			diff;
					logic        									ge;
    always_comb begin
        R_sh = {R[31:0], Q[31]};
        diff = {1'b0, R_sh} - {2'b00, D};
        ge   = ~diff[33];		// R_sh >= D
    end

    function automatic logic [31:0] abs32(input logic signed [31:0] x);
        return x[31] ? 32'(-x) : 32'(x);        // -2^31 maps to 2^31, correct as unsigned
    endfunction

    always_ff @(posedge clock, negedge reset_active_low) begin
        if (!rst_n) begin
            state <= S_IDLE; 
			busy <= 1'b0; 
			done <= 1'b0;
            quotient <= '0; 
			remainder <= '0; 
			div_by_zero <= 1'b0; 
			overflow <= 1'b0;
            D <= '0; 
			Q <= '0; 
			R <= '0; 
			count <= '0;
            neg_q <= 1'b0; 
			neg_r <= 1'b0; 
			dbz <= 1'b0; 
			dividend_q <= '0;
        end else begin
            done <= 1'b0;
            unique case (state)
                S_IDLE: begin
					if (start) begin
						D <= abs32(divisor);
						Q <= abs32(dividend);
						R <= '0;
						count <= '0;
						neg_q <= dividend[31] ^ divisor[31];
						neg_r <= dividend[31];
						dbz <= (divisor == 32'sd0);
						dividend_q <= dividend;
						busy <= 1'b1;
						state <= S_RUN;
					end
					else begin
						state <= S_IDLE;
					end
				end
                S_RUN: begin
					begin
						if (ge) begin
							R <= diff[32:0];
						end
						else begin
							R <= R_sh;
						end
					end
                    Q <= {Q[30:0], ge};
                    count <= count + 5'd1;
                    if (count == 5'd31) begin
						state <= S_FIX;
					end
                end

                S_FIX: begin
                    div_by_zero <= dbz;
                    overflow <= !dbz && !neg_q && neg_r && (Q == 32'h8000_0000);   // only -2^31 / -1
                    if (dbz) begin
                        quotient  <= -32'sd1;
                        remainder <= dividend_q;
                    end 
					else begin
						begin
							if (neg_q) begin
								quotient <= -$signed(Q);
							end
							else begin
								quotient <= $signed(Q);
							end
						end
						begin
							if (neg_r) begin
								remainder <= -$signed(R[31:0]);
							end
							else begin
								remainder <= $signed(R[31:0]);
							end
						end
                    end
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
	
endmodule