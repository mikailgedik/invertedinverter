/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`ifdef TESTING

function longint rol64(longint x, longint k);
	return (x << k) | (x >> (64 - k));
endfunction


typedef struct packed {
	longint s0;
  longint s1;
	longint s2;
	longint s3;
} Xoshiro256ssState;

typedef struct packed {
	Xoshiro256ssState state;
  longint result;
} Xoshiro256ssResult;


function Xoshiro256ssResult xoshiro256ss(Xoshiro256ssState state);
  longint result;
  longint t;
  Xoshiro256ssResult res;

	result = rol64(state.s1 * 5, 7) * 9;
	t = state.s1 << 17;

	state.s2 ^= state.s0;
	state.s3 ^= state.s1;
	state.s1 ^= state.s2;
	state.s0 ^= state.s3;

	state.s2 ^= t;
	state.s3 = rol64(state.s3, 45);

  res = { state, result };
	return res;
endfunction

function Xoshiro256ssResult initialize_from_32(int seed);
  Xoshiro256ssResult res;

  res.state = { (seed ^ 32'h43baba) * (seed ^ 32'habcd234), 192'h0, (seed ^ 32'h43baba) * (seed ^ 32'habcd234) };
  for(int i = 0; i < 10; i++) begin
    res = xoshiro256ss(res.state);
  end
	return res;
endfunction


// This module adds a synthetical delay of n clock cycles to the input
// It is also schmitt-triggered
// It is used to be able to simulate cirucal loops of logic (e.g. a circle of inverters)
// Every delay receives a seed value, so that runs are reporducible
// Every synthetical delay is also changed every time the output switches
// to simulate a little thermal variation etc.
module synthetical_delay(
  input wire A,
  output logic Y,
  input wire clk,
  input wire rst_n,
  input wire [31:0] rng_start
);
  logic [7:0] counter_q, counter_d, fixed_delay, lower_bound, upper_bound, offset;
  Xoshiro256ssResult rng_state, new_rng_state, initial_rng_state;
  localparam int MAX = 10;
  assign offset = 8'(rng_state.result);
  assign lower_bound = 8'(2) - (offset % 2) + fixed_delay;
  assign upper_bound = 8'(MAX - 2) + (offset % 2) - fixed_delay;
  assign new_rng_state = xoshiro256ss(rng_state.state);
  assign initial_rng_state = initialize_from_32(rng_start);
  
  always_comb begin
    counter_d = counter_q;
    if(A) begin
      if(counter_q < 8'(MAX)) counter_d = counter_q + 1;
    end else begin
      if(counter_q != 0) counter_d = counter_q - 1;
    end
  end
  always_ff @( posedge clk ) begin
    if(rst_n) begin
      counter_q <= counter_d;
      if (counter_q <= lower_bound) begin
        Y <= 0;
        rng_state <= new_rng_state;
      end else if (counter_q >= upper_bound) begin
        Y <= 1;
        rng_state <= new_rng_state;
      end else begin
        Y <= Y;
        rng_state <= rng_state;
      end
      fixed_delay <= fixed_delay;
    end else begin
      counter_q <= '0;
      Y <= '0;
      rng_state <= initial_rng_state;
      fixed_delay <= 8'(initial_rng_state.result % 2);
    end
  end
  initial begin
    // int kappa;
    // kappa = 1;
    // for(int i = 0; i < 10; i++) begin
    //   kappa = `weird_hash(kappa);
    //   $display("%x", kappa);
    // end
    for(int i = 0; i < 102; i++) @(posedge clk);
    $display("Synthetic delay with seed %x %d %d %d", rng_start, offset, fixed_delay, lower_bound, upper_bound);
    // forever begin
    //   @(posedge clk);
    //   $display("%d %d %x %b %b", lower_bound, upper_bound, counter_q, A, Y);
    // end
    
  end
endmodule

module sg13g2_inv_1(
  input wire A,
  output logic Y

  // Only for testing!!!!!
  , input wire clk,
  input wire rst_n,
  input wire [31:0] rng_start
);

  synthetical_delay delay(
    .A(~A),
    .Y(Y),
    .clk(clk),
    .rst_n(rst_n),
    .rng_start(rng_start)
  );

endmodule

module sg13g2_nor2_1(
  input wire A,
  input wire B,
  output logic Y

  // Only for testing!!!!!
  , input wire clk,
  input wire rst_n,
  input wire [31:0] rng_start
);
  synthetical_delay delay(
    .A(~(A | B)),
    .Y(Y),
    .clk(clk),
    .rst_n(rst_n),
    .rng_start(rng_start)
  );
endmodule

module sg13g2_mux2_1(
  input wire A0,
  input wire A1,
  input wire S,
  output wire X
);
  assign X = S ? A1 : A0;
endmodule

`endif // SIM

module inverter_chained #(
  parameter int AMOUNT = 3
) (
  input logic a,
  output logic y

  `ifdef TESTING
  , input wire clk,
  input wire rst_n
  `endif // TESTING
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

        `ifdef TESTING
        ,.clk(clk),
        .rst_n(rst_n),

        .rng_start(32'(i))
        `endif // TESTING

      );
    end
  endgenerate
endmodule

module simple_chain_loop #(
  parameter int AMOUNT = 1
) (
  input logic en,
  output logic r

  `ifdef TESTING
  , input wire clk,
  input wire rst_n
  `endif // TESTING
);
  inverter_chained #(
    .AMOUNT(AMOUNT)
  ) mylonginv (
    .a(en ? r : '0),
    .y(r)

    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif // TESTING
  );
endmodule

module multi_loops_intervined_1 #(
  parameter int L1 = 1,
  parameter int L2 = 1,
  parameter int L3 = 1
) (
  input logic en,
  output logic r

  `ifdef TESTING
  , input wire clk,
  input wire rst_n
  `endif // TESTING
);
  logic int1, int2, int3;
  inverter_chained #(
    .AMOUNT(L1)
  ) inv1_i (
    .a(int1),
    .y(int2)
    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif // TESTING

  );
  inverter_chained #(
    .AMOUNT(L2)
  ) inv2_i (
    .a(int1),
    .y(int3)
    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif // TESTING
  );

  inverter_chained #(
    .AMOUNT(L3)
  ) inv3_i (
    .a(en ? (int2 ^ int3): '0),
    .y(int1)
    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif // TESTING
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
    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif // TESTING

  );
  inverter_chained #(
    .AMOUNT(L1)
  ) inv1_i (
    .a(en ? matrix0_inter[1] : '0),
    .y(matrix0_inter[1])
    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif // TESTING

  );
  inverter_chained #(
    .AMOUNT(L2)
  ) inv2_i (
    .a(en ? matrix0_inter[2] : '0),
    .y(matrix0_inter[2])
    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif // TESTING

  );
  inverter_chained #(
    .AMOUNT(L3)
  ) inv3_i (
    .a(en ? matrix0_inter[3] : '0),
    .y(matrix0_inter[3])
    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif // TESTING

  );
  
  logic [2:0] matrix1_inter;
  logic matrix_1;
  inverter_chained #(
    .AMOUNT(L4)
  ) inv4_i (
    .a(en ? matrix1_inter[0] : '0),
    .y(matrix1_inter[0])
    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif // TESTING

  );
  inverter_chained #(
    .AMOUNT(L5)
  ) inv5_i (
    .a(en ? matrix1_inter[1] : '0),
    .y(matrix1_inter[1])
    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif // TESTING

  );
  inverter_chained #(
    .AMOUNT(L6)
  ) inv6_i (
    .a(en ? matrix1_inter[2] : '0),
    .y(matrix1_inter[2])
    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif // TESTING

  );

  always_ff @( posedge clk ) begin
    if (rst_n) begin
      matrix_0 <= matrix0_inter[0] ^ matrix0_inter[1] ^ matrix0_inter[2] ^ matrix0_inter[3];
      matrix_1 <= matrix_0 ^ matrix1_inter[0] ^ matrix1_inter[1] ^ matrix1_inter[2];
    end else begin
      matrix_0 <= '0;
      matrix_1 <= '0;
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
  input logic rst,
  input logic [RINGSIZE-1:0] cfg,
  output logic r

  `ifdef TESTING
  , input wire clk,
  input wire rst_n
  `endif // TESTING

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
        .B(rst),
        .Y(out_a)

        `ifdef TESTING
        ,.clk(clk),
        .rst_n(rst_n),

        .rng_start(32'(i))
        `endif // TESTING

      );
      sg13g2_nor2_1 nor_b (
        .A(input_b),
        .B(rst),
        .Y(out_b)

        `ifdef TESTING
        ,.clk(clk),
        .rst_n(rst_n),

        .rng_start(32'(i + RINGSIZE))
        `endif // TESTING
      );

      sg13g2_mux2_1 mux (
        .A0(out_a),
        .A1(out_b),
        .S(cfg[i]),
        .X(intermediate[i])
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
    for (i = 0; i < MAX_RINGSIZE; i++ ) begin: cfg_gen
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

    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif
  );

  simple_chain_loop #(
    .AMOUNT(31) // Odd
  ) chain_loop_1 (
    .en(conf[1]),
    .r(r[0][1])

    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif

  );

  simple_chain_loop #(
    .AMOUNT(301) // Odd
  ) chain_loop_2 (
    .en(conf[2]),
    .r(r[0][2])

    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif

  );

    simple_chain_loop #(
    .AMOUNT(1001) // Odd
  ) chain_loop_3 (
    .en(conf[3]),
    .r(r[0][3])

    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif

  );

  multi_loops_intervined_1 #(
    .L1(1),
    .L2(3), // Odd
    // Even: One further XOR between L1 and L2
    .L3(1) // Odd
  ) intervined_1 (
    .en(conf[4]),
    .r(r[0][4])

    `ifdef TESTING
    ,.clk(clk),
    .rst_n(rst_n)
    `endif

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
    .r(r[0][5])
  );
  
  assign r[0][6] = '0;
  assign r[0][7] = '0;
  
  generate
    for (i = 0; i < 8; i++) begin: pufs
      puf_1 #(
        // Has to be even!
        .RINGSIZE(8*i + 8)
      ) puf_i (
        .rst(conf[6 + i/4]),
        .cfg(cfg[(i*8 + 8)-1:0]),
        .r(r[1][i])

        `ifdef TESTING
        ,.clk(clk),
        .rst_n(rst_n)
        `endif

      );
    end
  endgenerate

  // To speed up tests, disable some RNGs
  // assign r[0][0] = 0;
  // assign r[0][1] = 0;
  // assign r[0][2] = 0;
  // assign r[0][3] = 0;
  // assign r[0][4] = 0;
  // assign r[0][5] = 0;
  // assign r[0][6] = 0;
  // assign r[0][7] = 0;

  // assign r[0][0] = 0;
  // assign r[1][1] = 0;
  // assign r[1][2] = 0;
  // assign r[1][3] = 0;
  // assign r[1][4] = 0;
  // assign r[1][5] = 0;
  // assign r[1][6] = 0;
  // assign r[1][7] = 0;
  
  generate
    for(i = 0; i < REGS; i++) begin: regs
      always_ff @( posedge clk ) begin
        if(rst_n) begin
          if(address == i && we) begin
            config_q[i] <= data_i;
          end
          else begin config_q[i] <= config_q[i]; end
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
