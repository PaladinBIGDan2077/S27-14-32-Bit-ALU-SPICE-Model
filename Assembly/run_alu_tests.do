# Questa: run from the folder that holds program.hex and expected_*.hex (cd there first, or copy them to the sim folder).
#   do run_alu_tests.do
# ALU type is picked in alu_cfg.svh. To override from here, add +define+ALU_UNSIGNED (or +define+ALU_SIGNED) to the vlog line.
# For a batch run: vsim -c ... -do "run -all; quit -f"   |   add +VERBOSE after the top name to print every vector.
quit -sim
if {[file exists work]} { vdel -lib work -all }
vlib work
vlog -sv +incdir+. top_module_alu_32b.sv alu_32bit_signed.sv adder_unit.sv multiplier_unit.sv divider_unit.sv alu_32bit_unsigned.sv tb_alu_32b.sv
vsim -voptargs=+acc work.tb_alu_32b
add wave -radix hex /tb_alu_32b/clock /tb_alu_32b/enable /tb_alu_32b/op_code /tb_alu_32b/vector_a /tb_alu_32b/vector_b
add wave -radix hex /tb_alu_32b/vector_result /tb_alu_32b/completed_op /tb_alu_32b/carry_out /tb_alu_32b/divide_by_zero_fault /tb_alu_32b/illegal_op_fault /tb_alu_32b/zeroed_vector_result
run -all
