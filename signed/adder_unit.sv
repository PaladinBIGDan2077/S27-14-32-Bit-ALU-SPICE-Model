module adder_subtractor_unit_signed
(
    input  			logic               							clock,
    input  			logic               							reset_active_low,      // active-low synchronous reset
    input  			logic               							start,
    input  			logic               							sub,
    input  			logic 			signed 			[31:0] 			a,
    input  			logic 			signed 			[31:0] 			b,
    output  		logic               							busy,
    output 			logic               							done,
    output 			logic 			signed 			[31:0] 			result,
    output 			logic               							overflow
);

					logic 							[31:0] 			A;
					logic							[31:0]			B;       // operands, shifted right each cycle (LSB first)
					logic							[30:0] 			S;          // sum bits collected so far
					logic											carry;
					logic 							[4:0]  			count;

					logic 											sum_bit;
					logic											carry_next;
					
    always_comb begin
        sum_bit    = A[0] ^ B[0] ^ carry;
        carry_next = (A[0] & B[0]) | (carry & (A[0] ^ B[0]));
    end

    always_ff @(posedge clock, negedge reset_active_low) begin
        if (!reset_active_low) begin
            busy <= 1'b0; 
			done <= 1'b0; 
			result <= '0; 
			overflow <= 1'b0;
            A <= '0; 
			B <= '0; 
			S <= '0; 
			carry <= 1'b0; 
			count <= '0;
        end 
		else begin
            done <= 1'b0;
            if (!busy) begin
                if (start) begin
                    A     <= a;
                    B     <= sub ? ~b : b;     // subtract: add inverted b with carry-in 1
                    carry <= sub;
                    count <= '0;
                    busy  <= 1'b1;
                end
            end 
			else begin
                A     <= {1'b0, A[31:1]};
                B     <= {1'b0, B[31:1]};
                S     <= {sum_bit, S[30:1]};   // after 31 shifts S holds bits 30..0 in place
                carry <= carry_next;
                count <= count + 5'd1;
                if (count == 5'd31) begin      // this cycle processes the sign bit
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    result   <= {sum_bit, S};
                    // operands' signs equal but result sign differs
                    overflow <= (A[0] == B[0]) && (sum_bit != A[0]);
                end
            end
        end
    end
	
endmodule