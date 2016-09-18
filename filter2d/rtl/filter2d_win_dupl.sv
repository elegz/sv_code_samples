//(c) Aleksandr Kotelnikov, al.kotelnikov@gmail.com

////////////////////////////////////////////////////////////////////
//            BUFFER                       WINDOW                 //
//                                                                //
//                                     ->BUF--*-------->-         //
//                                     |      |         |         //
// INPUT-*-------------->din[0]--->MUX-*>W----->MUX-->W-->MUX-->W //
//       |                       |                                //
//       |                       |     ->BUF--*-------->-         //
//       |                       |     |      |         |         //
//       ->FIFO-*------->din[1]--*-----*>W----->MUX-->W-->MUX-->W //
//              |                |                                //
//              |                |     ->BUF--*-------->-         //
//              |                |     |      |         |         //
//              ->FIFO-->din[2]--->MUX-*>W----->MUX-->W-->MUX-->W //
//                                                                //
////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module filter2d_win_dupl # (
   parameter FRAME_H    = 1080,
   parameter FRAME_W    = 1920,
   parameter DIN_WIDTH  = 8,
   parameter WIN_SIZE   = 3
) (
   input    wire                                               clk,
   input    wire                                               reset_n,
   input    wire                                               frame_start,
   input    wire                                               din_vld,
   input    wire                [WIN_SIZE-1:0][DIN_WIDTH-1:0]  din,
   output   wire                                               win_vld,
   output   reg   [WIN_SIZE-1:0][WIN_SIZE-1:0][DIN_WIDTH-1:0]  window
);
   import functions_pkg::clog2;

   localparam WIN_R   = WIN_SIZE / 2;
   localparam WIN_DLY = WIN_R + 1;

   reg                                                 frame_valid;
   reg                            [clog2(FRAME_H-1):0] raw_pointer;
   reg                            [clog2(FRAME_W-1):0] column_pointer;
   reg                            [       WIN_DLY-1:0] frame_start_z;
   reg                            [       WIN_DLY-1:0] din_vld_z;
   reg   [WIN_SIZE-1:0][WIN_R-1:0][     DIN_WIDTH-1:0] win_buf;
   reg                 [  WIN_R:1][    clog2(WIN_R):0] top_mux_addr;
   reg                 [  WIN_R:1][    clog2(WIN_R):0] bot_mux_addr;
   logic               [  WIN_R:1][     DIN_WIDTH-1:0] top_mux;
   logic               [  WIN_R:1][     DIN_WIDTH-1:0] bot_mux;
   
   //explicit connecting mux to data inputs
   genvar g;
   generate
      for (g = 1; g <= WIN_R; g++) begin: muxin
         wire [g:0][DIN_WIDTH-1:0] top_din;
         wire [g:0][DIN_WIDTH-1:0] bot_din;

         assign top_din = din[WIN_R+g:WIN_R];
         assign bot_din = din[WIN_R:WIN_R-g];
      end: muxin
   endgenerate

   assign win_vld = din_vld_z[WIN_DLY-1];

   //delay lines for some input signals
   always_ff @(posedge clk or negedge reset_n) begin: input_sig_delay
      if (~reset_n) begin
         din_vld_z <= '0;
      end else begin
         din_vld_z[WIN_DLY-1:1]     <= din_vld_z[WIN_DLY-2:0];
         din_vld_z[0]               <= din_vld;
      end
   end: input_sig_delay

   //top/bottom borders duplication via multiplexing raw buffers
   always_comb begin: mux_comb_logic
      for (int i = 1; i <= WIN_R; i++) begin
         top_mux[i] = muxin[i].top_din[top_mux_addr[i]];
         bot_mux[i] = muxin[WIN_R-i+1].bot_din[bot_mux_addr[i]];
      end
   end: mux_comb_logic

   always_ff @(posedge clk or negedge reset_n) begin: window_logic
      if (~reset_n) begin
         {window, win_buf, raw_pointer, column_pointer, top_mux_addr, bot_mux_addr, frame_valid} <= '0;
      end else if (frame_start) begin
         {raw_pointer, top_mux_addr, bot_mux_addr} <= '0;
         frame_valid <= '1;
      end else begin
         //buffer to support continuous streaming
         if (din_vld) begin
            win_buf[WIN_R][0] <= din[WIN_R];
            for (int i = 0; i < WIN_R; i++) begin
               win_buf[i][0]         <= bot_mux[i+1];
               win_buf[i+WIN_R+1][0] <= top_mux[i+1];
            end
         end

         if (din_vld_z[WIN_DLY-2] && frame_valid) begin
            //output column & raw
            if (column_pointer == (FRAME_W - 1)) begin
               column_pointer <= '0;
               raw_pointer++;
            end else begin
               column_pointer++;
            end

            //top/bottom borders duplication via multiplexing raw buffers
            if (column_pointer == (FRAME_W - WIN_R - 1)) begin
               for (int i = 1; i <= WIN_R; i++) begin
                  if (top_mux_addr[i] != i) begin
                     top_mux_addr[i]++;
                  end
                  if (raw_pointer >= (FRAME_H - WIN_R + i - 1)) begin
                     bot_mux_addr[i]++;
                  end
               end
            end

            if (!column_pointer) begin
               //load window from internal buffer regs
               for (int i = 0; i < WIN_SIZE; i++) begin
                  for (int j = 1; j <= WIN_R; j++) begin
                     window[i][j] <= win_buf[i][j-1];
                  end
               end
               //left border duplication
               for (int i = 0; i < WIN_SIZE; i++) begin
                  for (int j = WIN_R + 1; j < WIN_SIZE; j++) begin
                     window[i][j] <= win_buf[i][WIN_R-1];
                  end
               end
            end else begin
               //shifting raws through window
               //performing rigth border duplication, if window[i][0] is disabled
               //by column_pointer >= FRAME_W - WIN_R (1...n stages) 
               for (int i = 0; i < WIN_SIZE; i++) begin
                  window[i][WIN_SIZE-1:1] <= window[i][WIN_SIZE-2:0];
               end
            end

            //shifting raws through window
            //performing rigth border duplication, if window[i][0] is disabled
            //by column_pointer >= FRAME_W - WIN_R (0 stage)   
            if (column_pointer < (FRAME_W - WIN_R)) begin
               window[WIN_R][0] <= din[WIN_R];
               for (int i = 0; i < WIN_R; i++) begin
                  window[i][0]          <= bot_mux[i+1];
                  window[i+WIN_R+1][0]  <= top_mux[i+1];
               end
            end
         end

         if (raw_pointer == FRAME_H) begin
            frame_valid <= '0;
         end
      end
   end: window_logic
endmodule: filter2d_win_dupl