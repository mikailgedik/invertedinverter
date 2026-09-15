/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

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
  localparam int INVERTERS = 2 * 100 + 1;
  (* dont_touch = 1 *)
  (* keep = 1 *)
  logic inverter [INVERTERS-1:0];
  (* dont_touch = 1 *)
  (* keep = 1 *)
  logic enable_q;

  always_ff @( posedge clk ) begin
    if (~rst_n)
      enable_q <= ui_in[0];
    else
      enable_q <= '1;
  end
  // All output pins must be assigned. If not used, assign to 0.
  // assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;
  assign uo_out = inverter[7:0];

  generate
    genvar i;
    for (i = 0; i < INVERTERS - 1; i++) begin
      (* keep = 1 *)
      (* dont_touch = 1 *)
      assign inverter[i] = ~inverter[i + 1];
    end
  endgenerate
  
  (* dont_touch = 1 *)
  (* keep = 1 *)
  assign inverter[INVERTERS - 1] = ~inverter[0] & enable_q;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule
