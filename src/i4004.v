`include "def.v"

module i4004 (
    inout   [3:0]   data,   // data bus
    input           cp1,    // clock phase 1
    input           cp2,    // clock phase 2
    output          sync,   // sync output
    input           reset,  // reset
    input           test,   // test
    output          cm_rom, // memory control output
    output  [3:0]   cm_ram  // memory control output
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

    assign sync = machine_cycle[7];

    reg [11:0] program_counter;

    always @(posedge sync or negedge reset) begin
        if (~reset)
            program_counter <= 'b0;
        else if (instr_reg[7:4] == `OP_JCN && (
                (instr_reg[0] & (~test ^ instr_reg[3])) ||
                (instr_reg[1] & (carry ^ instr_reg[3])) ||
                (instr_reg[2] & ((accumulater == 4'b0) ^ instr_reg[3]))
                ))
            program_counter <= {program_counter[11:8], opr, opa};
        else if (instr_reg == 'b0 && opr == `OP_FIN && (opa & `FN_MSK) == `FN_FIN)
            program_counter <= program_counter;
        else if (instr_reg == 'b0 && opr == `OP_JIN && (opa & `FN_MSK) == `FN_JIN)
            program_counter <= {program_counter[11:8], index_reg[opa[3:1], 1'b0], index_reg[opa[3:1], 1'b1]};
        else if (instr_reg[7:4] == `OP_JUN)
            program_counter <= {instr_reg[3:0], opr, opa};
        else if (instr_reg[7:4] == `OP_JMS)
            program_counter <= {instr_reg[3:0], opr, opa};
        else if (instr_reg[7:4] == `OP_ISZ && index_reg[instr_reg[3:0]] != 4'b0)
            program_counter <= {program_counter[11:8], opr, opa};
        else if (instr_reg == 'b0 && opr == `OP_BBL)
            program_counter <= stack[0];
        else
            program_counter <= program_counter + 'b1;
    end

    reg [11:0] stack [2:0];

    always @(posedge sync or negedge reset) begin
        if (~reset) begin
            for (i = 0; i < 3; i = i + 1) begin
                stack[i] <= 'b0;
            end
        end
        else begin
            if (instr_reg[7:4] == `OP_JMS) begin
                stack[0] <= program_counter;
                stack[1] <= stack[0];
                stack[2] <= stack[1];
            end
            else if (instr_reg[7:4] == `OP_NOP && opr == `OP_BBL) begin
                stack[2] <= 'b0;
                stack[1] <= stack[2];
                stack[0] <= stack[1];
            end
        end
    end

    reg [3:0] opr;

    always @(negedge M1 or negedge reset) begin
        if (~reset)
            opr <= 'b0;
        else
            opr <= data;
    end

    reg [3:0] opa;

    always @(negedge M2 or negedge reset) begin
        if (~reset)
            opa <= 'b0;
        else
            opa <= data;
    end

    reg [7:0] instr_reg;

    always @(posedge sync or negedge reset) begin
        if (~reset)
            instr_reg <= 'b0;
        else if (instr_reg == 'b0 && 
                (opr == `OP_JCN ||
                 opr == `OP_FIM ||
                 opr == `OP_SRC ||
                 opr == `OP_FIN ||
                 opr == `OP_JUN ||
                 opr == `OP_JMS ||
                 opr == `OP_ISZ)
        )
            instr_reg <= {opr, opa};
        else
            instr_reg <= 'b0;
    end

    reg [3:0] index_reg [15:0];

    always @(posedge sync or negedge reset) begin
        if (~reset) begin
            for (i = 0; i < 16; i = i + 1) begin
                index_reg[i] <= 'b0;
            end
        end
        else if (instr_reg[7:4] == `OP_FIM && (instr_reg[3:0] & `FN_MSK) == `FN_FIM) begin
            index_reg[{instr_reg[3:1], 1'b0}] <= opr;
            index_reg[{instr_reg[3:1], 1'b1}] <= opa;
        end
        else if (instr_reg[7:4] == `OP_FIN && (instr_reg[3:0] & `FN_MSK) == `FN_FIN) begin
            index_reg[{instr_reg[3:1], 1'b0}] <= opr;
            index_reg[{instr_reg[3:1], 1'b1}] <= opa;
        end
        else if (instr_reg == 'b0 && opr == `OP_INC) begin
            index_reg[opa] <= index_reg[opa] + 'b1;
        end
        else if (instr_reg == 'b0 && opr == `OP_ISZ) begin
            index_reg[opa] <= index_reg[opa] + 'b1;
        end
        else if (instr_reg == 'b0 && opr == `OP_XCH) begin
            index_reg[opa] <= accumulater;
        end
    end

    reg [3:0]   accumulater;
    reg         carry;

    always @(negedge E2 or negedge reset) begin
        if (~reset) begin
            accumulater <= 'b0;
            carry <= 'b0;
        end
        else if (instr_reg == 'b0 && opr == `OP_ADD) begin
            {carry, accumulater} <= index_reg[opa] + accumulater + carry;
        end
        else if (instr_reg == 'b0 && opr == `OP_SUB) begin
            {carry, accumulater} <= index_reg[opa] - accumulater - carry;
        end
        else if (instr_reg == 'b0 && opr == `OP_LD) begin
            accumulater <= index_reg[opa];
        end
        else if (instr_reg == 'b0 && opr == `OP_XCH) begin
            accumulater <= index_reg[opa];
        end
        else if (instr_reg == 'b0 && opr == `OP_BBL) begin
            accumulater <= opa;
        end
        else if (instr_reg == 'b0 && opr == `OP_LDM) begin
            accumulater <= opa;
        end
    end

    always @(*) begin
        if (~reset) begin
            data = 4'bzzzz;
        end
        else if (A1) begin
            if (instr_reg == 'b0 && opr == `OP_FIN && (opa & `FN_MSK) == `FN_FIN)
                data = index_reg[1];
            else
                data = program_counter[3:0];
        end
        else if (A2) begin
            if (instr_reg == 'b0 && opr == `OP_FIN && (opa & `FN_MSK) == `FN_FIN)
                data = index_reg[0];
            else
                data = program_counter[7:4];
        end
        else if (A3) begin
            data = program_counter[11:8];
        end
        else if (E1) begin
            data = opa;
        end
        else if (E2) begin
            if (instr_reg == 'b0 && opr == `OP_SRC && (opa & `FN_MSK) == `FN_SRC)
                data = index_reg[{opa[3:1], 1'b0}];
            else
                data = 4'bzzzz;
        end
        else if (E3) begin
            if (instr_reg == 'b0 && opr == `OP_SRC && (opa & `FN_MSK) == `FN_SRC)
                data = index_reg[{opa[3:1], 1'b1}];
            else
                data = 4'bzzzz;
        end
        else begin
            data = 4'bzzzz;
        end
    end
    
endmodule