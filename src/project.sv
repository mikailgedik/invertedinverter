/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module inverter_chained_16 #(
  parameter int AMOUNT = 1
) (
  input logic a,
  output logic y
);
  logic [15:0] inverter [AMOUNT-1:0];
  assign inverter[0][0] = a;
  generate
    genvar i;
    for (i = 0; i < AMOUNT - 1; i++) begin
        // specify the inverter standart cell, so that yosys doesn't
        // have a stroke synthesiszing a combinatorial loop
      sg13g2_inv_16 direct_inv(
        .A( { inverter[i][0],inverter[i][1],inverter[i][2],inverter[i][3],
              inverter[i][4],inverter[i][5],inverter[i][6],inverter[i][7],
              inverter[i][8],inverter[i][9],inverter[i][10],inverter[i][11],
              inverter[i][12],inverter[i][13],inverter[i][14],inverter[i][15]
               } ),
        .Y( { inverter[i][1],inverter[i][2],inverter[i][3],inverter[i][4],
              inverter[i][5],inverter[i][6],inverter[i][7],inverter[i][8],
              inverter[i][9],inverter[i][10],inverter[i][11],inverter[i][12],
              inverter[i][13],inverter[i][14],inverter[i][15],inverter[i+1][0]
              } )
      );
    end
    sg13g2_inv_16 direct_inv(
      .A( { inverter[AMOUNT - 1][0],inverter[AMOUNT - 1][1],inverter[AMOUNT - 1][2],inverter[AMOUNT - 1][3],
            inverter[AMOUNT - 1][4],inverter[AMOUNT - 1][5],inverter[AMOUNT - 1][6],inverter[AMOUNT - 1][7],
            inverter[AMOUNT - 1][8],inverter[AMOUNT - 1][9],inverter[AMOUNT - 1][10],inverter[AMOUNT - 1][11],
            inverter[AMOUNT - 1][12],inverter[AMOUNT - 1][13],inverter[AMOUNT - 1][14],inverter[AMOUNT - 1][15]
              } ),
      .Y( { inverter[AMOUNT - 1][1],inverter[AMOUNT - 1][2],inverter[AMOUNT - 1][3],inverter[AMOUNT - 1][4],
            inverter[AMOUNT - 1][5],inverter[AMOUNT - 1][6],inverter[AMOUNT - 1][7],inverter[AMOUNT - 1][8],
            inverter[AMOUNT - 1][9],inverter[AMOUNT - 1][10],inverter[AMOUNT - 1][11],inverter[AMOUNT - 1][12],
            inverter[AMOUNT - 1][13],inverter[AMOUNT - 1][14],inverter[AMOUNT - 1][15],y
            } )
    );
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
  localparam AMOUNT = 400;
  logic enable_q;
  logic connector;
  
  always_ff @( posedge clk ) begin
    if (rst_n)
      enable_q <= ui_in[7] ? ui_in[0] : enable_q;
    else
      enable_q <= '1;
  end


  inverter_chained_16 #(
    .AMOUNT(AMOUNT)
  ) mylonginv (
    .a(~connector & enable_q),
    .y(connector)
  );

  assign uo_out = { enable_q, 1'b0,1'b0,1'b0,
                    1'b0,1'b0,1'b0, connector };

  // All output pins must be assigned. If not used, assign to 0.
  // assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule
