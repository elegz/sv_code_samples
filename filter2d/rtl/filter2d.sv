//(c) Aleksandr Kotelnikov, al.kotelnikov@gmail.com
`timescale 1ns/1ps

module filter2d # (
   parameter FRAME_H       = 1080,
   parameter FRAME_W       = 1920,
   parameter DIN_WIDTH     = 8,
   parameter DOUT_WIDTH    = 10,
   parameter WIN_SIZE      = 3,
   parameter FOUT_SHIFT    = 6,
   
   parameter bit [WIN_SIZE-1:0][WIN_SIZE-1:0][DIN_WIDTH-1:0] KERNEL = {
      8'd7,    8'd31,   8'd4,
      8'd29,   8'd123,  8'd21,
      8'd5,    8'd35,   8'd1
   }
) (
   input    wire                    clock,
   input    wire                    rst_n,
   input    wire                    frame_start,
   input    wire                    din_vld,
   input    wire  [ DIN_WIDTH-1:0]  din,
   output   wire                    dout_vld,
   output   wire  [DOUT_WIDTH-1:0]  dout
);
   wire                                               frame_start_buf;
   wire                                               din_vld_buf;
   wire                [WIN_SIZE-1:0][DIN_WIDTH-1:0]  din_buf;
   wire                                               win_vld;
   wire  [WIN_SIZE-1:0][WIN_SIZE-1:0][DIN_WIDTH-1:0]  window;

   filter2d_buffer # (
      .DIN_WIDTH        (DIN_WIDTH),
      .FRAME_W          (FRAME_W),
      .WIN_SIZE         (WIN_SIZE)
   ) filter2d_buffer_inst (
      .clk              (clock),
      .reset_n          (rst_n),
      .frame_start,
      .din_vld,
      .din,
      .din_vld_buf,
      .din_buf,
      .frame_start_buf
   );

   filter2d_win_dupl # (
      .DIN_WIDTH     (DIN_WIDTH),
      .FRAME_H       (FRAME_H),
      .FRAME_W       (FRAME_W),
      .WIN_SIZE      (WIN_SIZE)
   ) filter2d_win_dupl_inst (
      .clk           (clock),
      .reset_n       (rst_n),
      .frame_start   (frame_start_buf),
      .din_vld       (din_vld_buf),
      .din           (din_buf),
      .win_vld,
      .window
   );

   filter2d_core # (
      .DIN_WIDTH  (DIN_WIDTH),
      .DOUT_WIDTH (DOUT_WIDTH),
      .WIN_SIZE   (WIN_SIZE),
      .FOUT_SHIFT (FOUT_SHIFT)
   ) filter2d_core_inst (
      .clk        (clock),
      .reset_n    (rst_n),
      .kernel     (KERNEL),
      .win_vld,
      .window,
      .dout_vld,
      .dout
   );
endmodule: filter2d