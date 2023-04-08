module i4003 (
    input           cp,     // clock phase input
    input           data,   // data input
    output [9:0]    p_out,  // parallel outputs
    output          s_out,  // serial output
    input           e       // enable input
);

    reg [9:0]   shift_reg;
    reg         delay_reg;

    integer i;
    always @(posedge cp) begin
        for (i = 9; i > 0; i = i - 1) begin
            shift_reg[i] <= shift_reg[i - 1];
        end
        shift_reg[0] <= data;
    end

    always @(negedge cp) begin
        delay <= shift_reg[9];
    end

    assign s_out = delay_reg;

    initial begin
        shift_reg = 'b0;
        delay_reg = 'b0;
    end

endmodule