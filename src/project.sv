/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module inverter_chained #(
  parameter int AMOUNT = 1
) (
  input logic a,
  output logic y
);
  logic inverter [AMOUNT:0];
  assign inverter[0] = a;
  assign y = inverter[AMOUNT];
  generate
    genvar i;
    for (i = 0; i < AMOUNT; i++) begin
        // specify the inverter standart cell, so that yosys doesn't
        // have a stroke synthesiszing a combinatorial loop
      sg13g2_inv_1 direct_inv(
        .A( inverter[i] ),
        .Y( inverter[i+1] )
      );
    end
  endgenerate
endmodule

module simple_chain_loop #(
  parameter int AMOUNT = 1
) (
  input logic en,
  output logic r
);
  inverter_chained #(
    .AMOUNT(AMOUNT)
  ) mylonginv (
    .a(en ? r : '0),
    .y(r)
  );
endmodule

module multi_loops_intervined_1 #(
  parameter int L1 = 1,
  parameter int L2 = 1,
  parameter int L3 = 1
) (
  input logic en,
  output logic r
);
  logic int1, int2, int3;
  inverter_chained #(
    .AMOUNT(L1)
  ) inv1_i (
    .a(int1),
    .y(int2)
  );
  inverter_chained #(
    .AMOUNT(L2)
  ) inv2_i (
    .a(int1),
    .y(int3)
  );

  inverter_chained #(
    .AMOUNT(L3)
  ) inv3_i (
    .a(en ? (int2 ^ int3): '0),
    .y(int1)
  );
  assign r = int1;
endmodule

module multi_loops_intervined_2 #(
  parameter int L0 = 1,
  parameter int L1 = 1,
  parameter int L2 = 1,
  parameter int L3 = 1,
  parameter int L4 = 1,
  parameter int L5 = 1,
  parameter int L6 = 1
) (
  input logic en,
  input logic clk,
  input logic rst_n,
  output logic r
);
  logic [3:0] matrix0_inter;
  logic matrix_0;
  inverter_chained #(
    .AMOUNT(L0)
  ) inv0_i (
    .a(en ? matrix0_inter[0] : '0),
    .y(matrix0_inter[0])
  );
  inverter_chained #(
    .AMOUNT(L1)
  ) inv1_i (
    .a(en ? matrix0_inter[1] : '0),
    .y(matrix0_inter[1])
  );
  inverter_chained #(
    .AMOUNT(L2)
  ) inv2_i (
    .a(en ? matrix0_inter[2] : '0),
    .y(matrix0_inter[2])
  );
  inverter_chained #(
    .AMOUNT(L3)
  ) inv3_i (
    .a(en ? matrix0_inter[3] : '0),
    .y(matrix0_inter[3])
  );
  
  logic [3:0] matrix1_inter;
  logic matrix_1;
  inverter_chained #(
    .AMOUNT(L4)
  ) inv4_i (
    .a(en ? matrix1_inter[0] : '0),
    .y(matrix1_inter[0])
  );
  inverter_chained #(
    .AMOUNT(L5)
  ) inv5_i (
    .a(en ? matrix1_inter[1] : '0),
    .y(matrix1_inter[1])
  );
  inverter_chained #(
    .AMOUNT(L6)
  ) inv6_i (
    .a(en ? matrix1_inter[2] : '0),
    .y(matrix1_inter[2])
  );

  always_ff @( posedge clk ) begin
    if (rst_n) begin
      matrix_0 = matrix0_inter[0] ^ matrix0_inter[1] ^ matrix0_inter[2] ^ matrix0_inter[3];
      matrix_1 = matrix_0 ^ matrix1_inter[1] ^ matrix1_inter[2];
    end else begin
      matrix_0 = '0;
      matrix_1 = '0;
    end
  end
  assign r = matrix_1;
endmodule

// physically unclonable function 1
// bistable_ring_puf
module puf_1 #(
  // Has to be even!
  parameter int RINGSIZE = 2
) (
  input logic rst_n,
  input logic [RINGSIZE-1:0] cfg,
  output logic r
);

  logic [RINGSIZE:0] intermediate;

  generate
    genvar i;
    assign intermediate[RINGSIZE] = intermediate[0];
    assign r = intermediate[0];
    for(i = 0; i < RINGSIZE; i++) begin
      // TODO why are the demuxes needed?!
      // cfg[i] == 0 -> we select nor_a, else we select nor_b
      logic input_a, input_b, out_a, out_b;
      assign input_a = cfg[i] ? '0 : intermediate [i + 1];
      assign input_b = cfg[i] ? intermediate [i + 1] : '0;
      sg13g2_nor2_1 nor_a (
        .A(input_a),
        .B(~rst_n),
        .Y(out_a)
      );
      sg13g2_nor2_1 nor_b (
        .A(input_b),
        .B(~rst_n),
        .Y(out_b)
      );

      sg13g2_mux2_1 mux (
        .A(input_a),
        .B(input_b),
        .S(cfg[i]),
        .Y(intermediate[i])
      );
    end
  endgenerate

endmodule

module tt_um_mikailgedik_inverted_inverters (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
  localparam int MAX_RINGSIZE = 64;
  logic [1:0][7:0] r;
  localparam int REGS = 9;
  logic [REGS-1:0][7:0] config_q;
  logic [7:0] dout_q, dout_d;
  logic [5:0] address;
  logic we, read_src;
  logic [7:0] data_i;


  logic [MAX_RINGSIZE-1:0] cfg;
  logic [7:0] conf;

  generate
    genvar i;
    for (i = 0; i < MAX_RINGSIZE; i++ ) begin
      assign cfg[i] = config_q[i / 8][i % 8];
    end
  endgenerate
  assign conf = config_q[8];

  assign address = ui_in[5:0];
  assign read_src = ui_in[6];
  assign we = ui_in[7];
  assign uo_out = dout_q;
  assign data_i = uio_in;
  // All output pins must be assigned. If not used, assign to 0.
  assign uio_out = 0;
  assign uio_oe  = '0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

  simple_chain_loop #(
    .AMOUNT(3) // Odd
  ) chain_loop_0 (
    .en(conf[0]),
    .r(r[0][0])
  );

  simple_chain_loop #(
    .AMOUNT(31) // Odd
  ) chain_loop_1 (
    .en(conf[1]),
    .r(r[0][1])
  );

  simple_chain_loop #(
    .AMOUNT(301) // Odd
  ) chain_loop_2 (
    .en(conf[2]),
    .r(r[0][2])
  );

  multi_loops_intervined_1 #(
    .L1(1),
    .L2(3), // Odd
    // Even: One further XOR between L1 and L2
    .L3(1) // Odd
  ) intervined_1 (
    .en(conf[4]),
    .r(r[0][3])
  );

  multi_loops_intervined_2 #(
    .L1(1),
    .L2(3),
    .L3(5),
    .L4(7),
    .L5(11),
    .L6(13)
  ) intervined_2 (
    .clk(clk),
    .rst_n(rst_n),
    .en(conf[5]),
    .r(r[0][4])
  );
  
  assign r[0][5] = '0;
  assign r[0][6] = '0;
  assign r[0][7] = '0;
  
  generate
    for (i = 0; i < 8; i++ ) begin
      puf_1 #(
        // Has to be even!
        .RINGSIZE(8*i + 8)
      ) puf_i (
        .rst_n(conf[6 + i/4]),
        .cfg(cfg[(i*8 + 8)-1:0]),
        .r(r[1][i])
      );
    end
  endgenerate

  generate
    for(i = 0; i < REGS; i++) begin
      always_ff @( posedge clk ) begin
        if(rst_n) begin
          if(address == i && we) config_q[i] <= data_i;
          else config_q[i] <= config_q[i];
        end else begin
          config_q[i] <= '0;
        end
      end
    end
  endgenerate

  always_comb begin
    dout_d = '0;
    if (read_src) begin
      dout_d = config_q[address];
    end else begin
      dout_d = r[address];
    end
  end

  always_ff @( posedge clk ) begin
    if(rst_n) begin
      dout_q <= dout_d;
    end else begin
      dout_q <= '0;
    end
  end
endmodule
