`include "def.v"

module i4001 #(
    parameter ID = 0
) (
    inout [3:0] data,   // data bus
    input       cp1,    // clock phase 1
    input       cp2,    // clock phase 2
    input       sync,   // sync input from 4004
    input       reset,  // reset
    input       cl,     // clear input for I/O lines
    input       cm,     // memory control input
    inout [3:0] io      // I/O lines
);

    reg [7:0] machine_cycle;
    wire A1 = ~machine_cycle[0];
    wire A2 = ~machine_cycle[1];
    wire A3 = ~machine_cycle[2];
    wire M1 = ~machine_cycle[3];
    wire M2 = ~machine_cycle[4];
    wire E1 = ~machine_cycle[5];
    wire E2 = ~machine_cycle[6];
    wire E3 = ~machine_cycle[7];

    integer i;
    always @(posedge cp2 or negedge reset) begin
        if (~reset) begin
            machine_cycle <= 8'b01111111;
        end
        else begin
            for (i = 7; i > 0; i = i - 1) begin
                machine_cycle[i] <= machine_cycle[i - 1];
            end
            machine_cycle[0] <= machine_cycle[7];
        end
    end

    reg [11:0] address_reg;

    always @(negedge A1 or negedge reset)
        address_reg[3:0] <= ~reset ? 'b0 : data;
    always @(negedge A2 or negedge reset)
        address_reg[7:4] <= ~reset ? 'b0 : data;
    always @(negedge A3 or negedge reset)
        address_reg[11:8] <= ~reset ? 'b0 : data;

    // TODO: metal option
    wire enable = cm && (address_reg[11:8] == ID);

    reg [3:0] opr;

    always @(negedge M1 or negedge reset)
        opr <= ~reset ? 'b0 : data;

    reg [3:0] opa;

    always @(negedge M2 or negedge reset)
        opa <= ~reset ? 'b0 : data;

    reg [7:0] instr_reg;

    always @(posedge sync or negedge reset) begin
        if (~reset)
            instr_reg <= 'b0;
        else if (instr_reg == 'b0 && opr == `OP_SRC)
            instr_reg <= {opr, opa};
        else
            instr_reg <= 'b0;
    end

    reg [7:0] rom_array [255:0];

    initial begin

    end

    reg [3:0] output_reg;

    always @(negedge E2 or negedge reset) begin
        if (~reset || ~cl)
            output_reg <= 'b0;
        else if (enable && instr_reg[7:4] == `OP_SRC && opr == `OP_IOR && opa == `FN_WRR)
            output_reg <= data;
    end

    reg [3:0] io_signal;

    always @(*) begin
        if (~reset)
            io_signal = 4'bzzzz;
        else if (enable && instr_reg[7:4] == `OP_SRC && opr == `OP_IOR && opa == `FN_RDR)
            io_signal = 4'bzzzz;
        else
            io_signal = output_reg;
    end

    assign io = io_signal;

    reg [3:0] data_signal;

    always @(*) begin
        if (~reset)
            data_signal = 4'bzzzz;
        else if (M1)
            data_signal = enable ? rom_array[address_reg[7:0]][7:4] : 4'bzzzz;
        else if (M2)
            data_signal = enable ? rom_array[address_reg[7:0]][3:0] : 4'bzzzz;
        else if (E2 && enable && instr_reg[7:4] == `OP_SRC && opr == `OP_IOR && opa == `FN_RDR)
            data_signal = io;
        else
            data_signal = 4'bzzzz;
    end

    assign data = data_signal;

endmodule