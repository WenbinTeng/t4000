module i4002 #(
    parameter ID = 0
) (
    inout [3:0] data,   // data bus
    input       cp1,    // clock phase 1
    input       cp2,    // clock phase 2
    input       sync,   // sync input
    input       reset,  // reset
    input       p0,     // hard wired chip select input
    input       cm,     // memory control input
    inout [3:0] out     // output lines
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
        address_reg[3:0] <= reset ? data : 'b0;
    always @(negedge A2 or negedge reset)
        address_reg[7:4] <= reset ? data : 'b0;
    always @(negedge A3 or negedge reset)
        address_reg[11:8] <= reset ? data : 'b0;

    // TODO: metal option
    wire enable = cm && (address_reg[11:10] == ID);

    reg [3:0] opr;

    always @(negedge M1 or negedge reset)
        opr <= reset ? data : 'b0;

    reg [3:0] opa;

    always @(negedge M2 or negedge reset)
        opa <= reset ? data : 'b0;

    reg [7:0] instr_reg;

    always @(posedge sync or negedge reset) begin
        if (~reset)
            instr_reg <= 'b0;
        else if (instr_reg == 'b0 && opr == `OP_SRC)
            instr_reg <= {opr, opa};
        else
            instr_reg <= 'b0;
    end

    reg [7:0] src_reg;

    always @(negedge E2 or negedge reset) begin
        if (~reset)
            src_reg[3:0] <= 'b0;
        else if (instr_reg == 'b0 && opr == `OP_SRC)
            src_reg[3:0] <= data;
    end
    always @(negedge E3 or negedge reset) begin
        if (~reset)
            src_reg[7:4] <= 'b0;
        else if (instr_reg == 'b0 && opr == `OP_SRC)
            src_reg[7:4] <= data;
    end

    reg [3:0] memory_array [63:0];

    always @(negedge E2 or negedge reset) begin
        if (~reset) begin
            for (i = 0; i < 64; i = i + 1) begin
                memory_array[i] <= 'b0;
            end
        end
        else if (enable && instr_reg[7:4] == `OP_SRC && opr == `OP_IOR && opa == `FN_WRM) begin
            memory_array[src_reg[5:0]] <= data;
        end
    end

    reg [3:0] status_array [15:0];

    always @(negedge E2 or negedge reset) begin
        if (~reset) begin
            for (i = 0; i < 16; i = i + 1) begin
                status_array[i] <= 'b0;
            end
        end
        else if (enable && instr_reg[7:4] == `OP_SRC && opr == `OP_IOR && opa[3:2] == 2'b01) begin
            status_array[{src_reg[5:4], opa[1:0]}] <= data;
        end
    end

    reg [3:0] output_reg;

    always @(negedge E2 or negedge reset) begin
        if (~reset)
            output_reg <= 'b0;
        else if (enable && instr_reg[7:4] == `OP_SRC && opr == `OP_IOR && opa == `FN_WMP)
            output_reg <= data;
    end

    always @(*) begin
        if (~reset)
            out <= 4'bzzzz;
        else
            out <= output_reg;
    end

    always @(*) begin
        if (~reset)
            data = 4'bzzzz;
        else if (E2 && enable && instr_reg[7:4] == `OP_SRC && opr == `OP_IOR && (opa == `FN_SBM || opa == `FN_RDM || opa == `FN_ADM))
            data = memory_array[src_reg[5:0]];
        else if (E2 && enable && instr_reg[7:4] == `OP_SRC && opr == `OP_IOR && opa[3:2] == 2'b11)
            data = status_array[{src_reg[5:4], opa[1:0]}];
        else
            data = 4'bzzzz;
    end

endmodule