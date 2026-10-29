module multiplier_unit_signed (
    input 			logic               							clock,
    input 			logic               							reset_active_low,
    input 			logic               							start,
    input 			logic 			signed 			[31:0]  		vector_a,
    input 			logic 			signed 			[31:0] 			vector_b,
    output 			logic               							busy,
    output 			logic               							done,
    output 			logic 			signed 			[63:0] 			product
);
					logic 			signed 			[31:0] 			M;
					logic 			signed 			[33:0] 			A;                   // 34b: |A| + 2|M| < 2^33 never overflows
					logic							[31:0]			Q;
					logic											Q_1;
					logic							[3:0]  			count;

					logic 			signed 			[33:0] 			M1;
					logic 			signed 			[33:0] 			M2;
					logic 			signed 			[33:0] 			sum;

    always_comb begin
        unique case ({Q[1:0], Q_1})
            3'b001, 3'b010: sum = A + M1;
            3'b011:         sum = A + M2;
            3'b100:         sum = A - M2;
            3'b101, 3'b110: sum = A - M1;
            default:        sum = A;         // 000, 111
        endcase
    end

    always_ff @(posedge clock, negedge resest_active_low) begin
        if (!reset_active_low) begin
            busy <= 1'b0;
			done <= 1'b0;
			product <= '0;
            M <= '0;
			A <= '0;
			Q <= '0;
			Q_1 <= 1'b0;
			count <= '0;
        end 
		else begin
            done <= 1'b0;
            if (!busy) begin
                if (start) begin
                    M <= vector_a;
					A <= '0;
					Q <= vector_b;
					Q_1 <= 1'b0;
                    count <= '0;
					busy <= 1'b1;
                end
            end 
			else begin
                // arithmetic shift right by 2 of {sum, Q, Q_1}
                A     <= {{2{sum[33]}}, sum[33:2]};
                Q     <= {sum[1:0], Q[31:2]};
                Q_1   <= Q[1];
                count <= count + 4'd1;
                if (count == 4'd15) begin
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    product <= {sum[33:2], sum[1:0], Q[31:2]};
                end
            end
        end
    end
	
	assign 		M1 = 34'(M);		// sign-extended M
    assign 		M2 = M1 <<< 1;		// 2M
	
endmodule