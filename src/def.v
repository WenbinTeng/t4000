/* operation code */
`define OP_NOP  4'b0000
`define OP_JCN  4'b0001
`define OP_FIM  4'b0010
`define OP_SRC  4'b0010
`define OP_FIN  4'b0011
`define OP_JIN  4'b0011
`define OP_JUN  4'b0100
`define OP_JMS  4'b0101
`define OP_INC  4'b0110
`define OP_ISZ  4'b0111
`define OP_ADD  4'b1000
`define OP_SUB  4'b1001
`define OP_LD   4'b1010
`define OP_XCH  4'b1011
`define OP_BBL  4'b1100
`define OP_LDM  4'b1101
`define OP_IOR  4'b1110
`define OP_ACC  4'b1111

/* function code */
`define FN_MSK  4'b0001
`define FN_FIM  4'b0000
`define FN_SRC  4'b0001
`define FN_FIN  4'b0000
`define FN_JIN  4'b0001
`define FN_WRM  4'b0000
`define FN_WMP  4'b0001
`define FN_WRR  4'b0010
`define FN_WR0  4'b0100
`define FN_WR1  4'b0101
`define FN_WR2  4'b0110
`define FN_WR3  4'b0111
`define FN_SBM  4'b1000
`define FN_RDM  4'b1001
`define FN_RDR  4'b1010
`define FN_ADM  4'b1011
`define FN_RD0  4'b1100
`define FN_RD1  4'b1101
`define FN_RD2  4'b1110
`define FN_RD3  4'b1111
`define FN_CLB  4'b0000
`define FN_CLC  4'b0001
`define FN_IAC  4'b0010
`define FN_CMC  4'b0011
`define FN_CMA  4'b0100
`define FN_RAL  4'b0101
`define FN_RAR  4'b0110
`define FN_TCC  4'b0111
`define FN_DAC  4'b1000
`define FN_TCS  4'b1001
`define FN_STC  4'b1010
`define FN_DAA  4'b1011
`define FN_KBP  4'b1100
`define FN_DCL  4'b1101