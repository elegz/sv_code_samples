//(c) Aleksandr Kotelnikov, al.kotelnikov@gmail.com

///////////////////////////////////////////////////
//                   BUFFER                      //
//                                               //
//       -->din-*--------------din_buf[0]-->     //
//              |                                //
//              ->FIFO-*-------din_buf[1]-->     //
//                     |                         //
//                     ->FIFO--din_buf[2]-->     //
//                                               //
// BUFFER_SIZE = (WINDOW_SIZE - 1) * FRAME_WIDTH //
///////////////////////////////////////////////////

`timescale 1ns/1ps

module filter2d_buffer # (
   parameter FRAME_H    = 1080,
   parameter FRAME_W    = 1920,
   parameter DIN_WIDTH  = 8,
   parameter WIN_SIZE   = 3
) (
   input    wire                                clk,
   input    wire                                reset_n,
   input    wire                                frame_start,
   input    wire                                din_vld,
   input    wire               [DIN_WIDTH-1:0]  din,
   output   reg                                 frame_start_buf,
   output   wire                                din_vld_buf,
   output   wire [WIN_SIZE-1:0][DIN_WIDTH-1:0]  din_buf
);
   import functions_pkg::clog2;

   localparam ENDING_SIZE  = (WIN_SIZE - 1) * FRAME_W - 1;
   localparam WIN_R        = WIN_SIZE / 2;

   wire                          frame_ending_buf;
   logic                         wren;
   reg  [clog2(ENDING_SIZE):0]   ending_counter;
   reg                           frame_valid;
   reg  [    clog2(FRAME_W):0]   column_counter;
   reg  [    clog2(FRAME_H):0]   raw_counter;
   reg  [        WIN_SIZE-1:0]   raw_buf_vld;
   reg                           buffer_fsm_out;
   reg                           frame_recovery;

   assign din_vld_buf   = din_vld;
   assign din_buf[0]    = din;

   assign frame_ending_buf = buffer_fsm_out;

   enum logic [2:0] {IDLE = 3'b001, WR_FRAME = 3'b010, RD_ENDING = 3'b100} buffer_fsm_state;
   
   always_ff @(posedge clk or negedge reset_n) begin: buffer_fsm
      if(~reset_n) begin
          buffer_fsm_state <= IDLE;
          buffer_fsm_out   <= '0;
      end else begin
         case (buffer_fsm_state)
            IDLE: begin
               if (frame_start) begin
                  buffer_fsm_state <= WR_FRAME;
               end
               buffer_fsm_out <= '0;
            end
            WR_FRAME: begin
               if (raw_counter == FRAME_H) begin
                  buffer_fsm_state <= RD_ENDING;
               end
               buffer_fsm_out <= '0;
            end
            RD_ENDING: begin
               if (ending_counter == ENDING_SIZE) begin
                  if (frame_valid) begin 
                     buffer_fsm_state <= WR_FRAME;
                  end else begin
                     buffer_fsm_state <= IDLE;
                  end
               end
               buffer_fsm_out <= '1;
            end
            default: begin
               buffer_fsm_state  <= IDLE;
               buffer_fsm_out    <= '0;
            end
         endcase
      end
   end: buffer_fsm

   always_comb begin: buffer_comb_logic
      wren = frame_valid & din_vld;
   end: buffer_comb_logic

   always_ff @(posedge clk or negedge reset_n) begin: buffer_sync_logic
      if(~reset_n) begin
         {column_counter, raw_counter, raw_buf_vld, ending_counter}  <= '0;
         {frame_recovery, frame_start_buf, frame_valid}              <= '0;
      end else begin
         if (frame_start) begin
            {column_counter, raw_counter, raw_buf_vld} <= '0;
            frame_valid <= '1;
         end else begin
            if (wren) begin
               if (column_counter == (FRAME_W - 1)) begin
                  raw_counter++;
                  raw_buf_vld[WIN_SIZE-1:1]  <= raw_buf_vld[WIN_SIZE-2:1]; 
                  raw_buf_vld[1]             <= '1;
                  frame_recovery             <= raw_buf_vld[WIN_R]; //choose another flag for shorter frame gap
                  frame_start_buf            <= raw_buf_vld[WIN_R] & ~frame_recovery;
                  column_counter             <= '0;
               end else begin
                  column_counter++;
               end
            end

            if (frame_ending_buf) begin
               ending_counter++;
            end else begin
               ending_counter <= '0;
            end

            if (raw_counter == FRAME_H) begin
               frame_valid <= '0;
            end
         end
      end
   end: buffer_sync_logic

   genvar g;
   generate
      for (g = 1; g < WIN_SIZE; g++) begin: fifo_chain
         fifo raw_buffer (
            .clk,
            .reset      (~reset_n),
            .wre        ((g == 1) ? wren : (frame_ending_buf | (wren & raw_buf_vld[g-1]))),
            .data_in    (din_buf[g-1]),
            .rde        (frame_ending_buf | (wren & raw_buf_vld[g])),
            .data_out   (din_buf[g])
         );
      end: fifo_chain
   endgenerate
endmodule: filter2d_buffer