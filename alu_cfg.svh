// alu_cfg.svh -- the ONE place that picks the ALU type. Included by top_module_alu_32b.sv and tb_alu_32b.sv so the
// design and the testbench always agree (a define inside one .sv file would not reach the other file in Questa).
//   Default below = SIGNED. For the unsigned ALU change it to `define ALU_UNSIGNED, or leave this file alone and pass
//   +define+ALU_UNSIGNED / +define+ALU_SIGNED to vlog (a command-line define wins over the default).
`ifndef ALU_CFG_SVH
`define ALU_CFG_SVH
`ifndef ALU_SIGNED
  `ifndef ALU_UNSIGNED
    `define ALU_SIGNED
  `endif
`endif
`ifdef ALU_SIGNED
  `ifdef ALU_UNSIGNED
    `error "Define only one of ALU_SIGNED / ALU_UNSIGNED"
  `endif
`endif
`endif
