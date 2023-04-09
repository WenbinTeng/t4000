module top (
    input           cp1,    // clock phase 1
    input           cp2,    // clock phase 2
    input           test,   // external test signal
    input           reset,  // external reset signal
    input           cl,     // clear output port
    inout   [63:0]  rom_io, // rom I/O port
    inout   [63:0]  ram_io, // ram I/O port
    output  [10:0]  sr_io   // shift register I/O port
);
    
    wire            sync;
    wire            cm_rom;
    wire    [3:0]   cm_ram;
    wire    [3:0]   data;

    genvar i, j;
    generate
        for (i = 0; i < 16; i = i + 1) begin
            i4001 #(.ID(i)) u_i4001 (
                .data   (data),
                .cp1    (cp1),
                .cp2    (cp2),
                .sync   (sync),
                .reset  (reset),
                .cl     (cl),
                .cm     (cm_rom),
                .io     (rom_io[i*4+3:i*4])
            );
        end
    endgenerate
    generate
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                i4002 #(.ID(j)) u_i4002 (
                    .data   (data),
                    .cp1    (cp1),
                    .cp2    (cp2),
                    .sync   (sync),
                    .reset  (reset),
                    .p0     (1'b0),
                    .cm     (cm_ram[i]),
                    .out    (ram_io[i*16+j*4+3:i*16+j*4])
                );
            end
        end
    endgenerate

    i4003 u_i4003 (
        .cp     (rom_io[63]),
        .data   (rom_io[62]),
        .p_out  (sr_io[9:0]),
        .s_out  (sr_io[10]),
        .e      (rom_io[61])
    );

    i4004 u_i4004 (
        .data   (data),
        .cp1    (cp1),
        .cp2    (cp2),
        .sync   (sync),
        .reset  (reset),
        .test   (test),
        .cm_rom (cm_rom),
        .cm_ram (cm_ram)
    );

endmodule