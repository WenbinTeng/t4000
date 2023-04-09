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
            program_counter <= {program_counter[11:8], index_reg[{opa[3:1], 1'b0}], index_reg[{opa[3:1], 1'b1}]};
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
        else if (instr_reg[7:4] == `OP_JMS) begin
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
        else if (instr_reg == 'b0 && (
                    opr == `OP_JCN ||
                    opr == `OP_FIM ||
                    opr == `OP_SRC ||
                    opr == `OP_FIN ||
                    opr == `OP_JUN ||
                    opr == `OP_JMS ||
                    opr == `OP_ISZ
        ))
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
        else if (instr_reg == 'b0 && opr == `OP_ADD)
            {carry, accumulater} <= index_reg[opa] + accumulater + carry;
        else if (instr_reg == 'b0 && opr == `OP_SUB)
            {carry, accumulater} <= index_reg[opa] - accumulater - carry;
        else if (instr_reg == 'b0 && opr == `OP_LD)
            accumulater <= index_reg[opa];
        else if (instr_reg == 'b0 && opr == `OP_XCH)
            accumulater <= index_reg[opa];
        else if (instr_reg == 'b0 && opr == `OP_BBL)
            accumulater <= opa;
        else if (instr_reg == 'b0 && opr == `OP_LDM)
            accumulater <= opa;
        else if (instr_reg == `OP_SRC && opr == `OP_IOR && opa == `FN_SBM)
            {carry, accumulater} <= -data + accumulater - carry;
        else if (instr_reg == `OP_SRC && opr == `OP_IOR && opa == `FN_RDM)
            accumulater <= data;
        else if (instr_reg == `OP_SRC && opr == `OP_IOR && opa == `FN_RDR)
            accumulater <= data;
        else if (instr_reg == `OP_SRC && opr == `OP_IOR && opa == `FN_ADM)
            {carry, accumulater} <= data + accumulater + carry;
        else if (instr_reg == `OP_SRC && opr == `OP_IOR && (opa == `FN_RD0 || opa == `FN_RD1 || opa == `FN_RD2 || opa == `FN_RD3))
            accumulater <= data;
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_CLB)
            {carry, accumulater} <= 'b0;
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_CLC)
            carry <= 0;
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_IAC)
            accumulater <= accumulater + 'b1;
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_CMC)
            carry <= ~carry;
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_CMA)
            accumulater <= ~accumulater;
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_RAL)
            {carry, accumulater} <= {accumulater, carry};
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_RAR)
            {accumulater, carry} <= {carry, accumulater};
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_TCC)
            {carry, accumulater} <= {4'b0, carry};
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_DAC)
            accumulater <= accumulater - 'b1;
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_TCS)
            {carry, accumulater} <= {1'b0, carry ? 4'b1010 : 4'b1001};
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_STC)
            carry <= 'b1;
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_DAA)
            {carry, accumulater} <= accumulater + (carry || accumulater >= 4'b1010 ? 4'b0110 : 4'b0000);
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_KBP)
            accumulater <= (
                accumulater == 4'b0000 ||
                accumulater == 4'b0001 ||
                accumulater == 4'b0010 ||
                accumulater == 4'b0100 ||
                accumulater == 4'b1000
            ) ? accumulater : 4'b1111;
    end

    reg [3:0] cm_ram_reg;

    always @(negedge E2 or negedge reset) begin
        if (~reset)
            cm_ram_reg <= 'b0;
        else if (instr_reg == 'b0 && opr == `OP_ACC && opa == `FN_DCL)
            cm_ram_reg <= accumulater;
    end

    assign cm_ram = cm_ram_reg;
    assign cm_rom = 1'b1;

    reg [3:0] data_signal;

    always @(*) begin
        if (~reset) begin
            data_signal = 4'bzzzz;
        end
        else if (A1) begin
            if (instr_reg == 'b0 && opr == `OP_FIN && (opa & `FN_MSK) == `FN_FIN)
                data_signal = index_reg[1];
            else
                data_signal = program_counter[3:0];
        end
        else if (A2) begin
            if (instr_reg == 'b0 && opr == `OP_FIN && (opa & `FN_MSK) == `FN_FIN)
                data_signal = index_reg[0];
            else
                data_signal = program_counter[7:4];
        end
        else if (A3) begin
            data_signal = program_counter[11:8];
        end
        else if (E1) begin
            data_signal = opa;
        end
        else if (E2) begin
            if (instr_reg == 'b0 && opr == `OP_SRC && (opa & `FN_MSK) == `FN_SRC)
                data_signal = index_reg[{opa[3:1], 1'b0}];
            else if (opr == `OP_IOR && (
                        opa == `FN_WRM ||
                        opa == `FN_WMP ||
                        opa == `FN_WRR ||
                        opa == `FN_WR0 ||
                        opa == `FN_WR1 ||
                        opa == `FN_WR2 ||
                        opa == `FN_WR3
            ))
                data_signal = accumulater;
            else
                data_signal = 4'bzzzz;
        end
        else if (E3) begin
            if (instr_reg == 'b0 && opr == `OP_SRC && (opa & `FN_MSK) == `FN_SRC)
                data_signal = index_reg[{opa[3:1], 1'b1}];
            else
                data_signal = 4'bzzzz;
        end
        else begin
            data_signal = 4'bzzzz;
        end
    end
    
    assign data = data_signal;

endmodule