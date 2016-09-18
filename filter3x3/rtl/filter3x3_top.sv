//(c) Aleksandr Kotelnikov, al.kotelnikov@gmail.com
`timescale 1ns/1ps

module filter3x3_top import filter3x3_pkg::*; (
   input    wire                    clock,
   input    wire                    rst_n,
   input    wire                    frame_start,
   input    wire                    din_vld,
   input    wire  [ DIN_WIDTH-1:0]  din,
   output   wire                    dout_vld,
   output   wire  [DOUT_WIDTH-1:0]  dout
);
  filter2d # (
   .FRAME_H    (FRAME_H),
   .FRAME_W    (FRAME_W),
   .DIN_WIDTH  (DIN_WIDTH),
   .DOUT_WIDTH (DOUT_WIDTH),
   .WIN_SIZE   (WIN_SIZE),
   .KERNEL     (KERNEL),
   .FOUT_SHIFT (FOUT_SHIFT)
) filter3x3 (
   .clock,
   .rst_n,
   .frame_start,
   .din_vld,
   .din,
   .dout_vld,
   .dout
);
endmodule: filter3x3_top