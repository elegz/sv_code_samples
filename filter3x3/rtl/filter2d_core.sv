//(c) Aleksandr Kotelnikov, al.kotelnikov@gmail.com

/////////////////////////////////////////
//               FILTER                //
//                                     //
// K*W K*W K*W K*W K*W K*W K*W K*W K*W //
//  |   |   |   |   |   |   |   |   |  //
// reg reg reg reg reg reg reg reg reg //
//   \/      \/      \/      \/     |  //
//   +       +       +       +      |  //
//   |       |       |       |      |  //
//  reg     reg     reg     reg    reg //
//     \   /           \   /        |  //
//       +               +          |  //
//        \             /           |  //        
//        reg         reg          reg //
//          \        /             /   //
//            \    /             /     //
//              +              /       //
//               \           /         //
//               reg      reg          //
//                  \    /             //
//                    +                //
//                    |                //
//                   reg               //
//                                     //
/////////////////////////////////////////

`timescale 1ns/1ps
`include "filter2d_defines.svh"

`ifdef DSP_FULL_ON
   `USE_DSP
`endif
module filter2d_core # (
   parameter DIN_WIDTH        = 8,
   parameter DOUT_WIDTH       = 10,
   parameter WIN_SIZE         = 3,
   parameter FOUT_SHIFT       = 6
) (
   input    wire                                                  clk,
   input    wire                                                  reset_n,
   input    wire  [WIN_SIZE-1:0][WIN_SIZE-1:0][ DIN_WIDTH-1:0]    kernel,
   input    wire                                                  win_vld,
   input    wire  [WIN_SIZE-1:0][WIN_SIZE-1:0][ DIN_WIDTH-1:0]    window,
   output   wire                                                  dout_vld,
   output   wire                              [DOUT_WIDTH-1:0]    dout
);
   import functions_pkg::clog2;

   localparam WIN_SQR          = WIN_SIZE * WIN_SIZE;
   localparam SUM_STAGE_NUM    = clog2(WIN_SQR);

   wire                         [ WIN_SQR-1:0][2*DIN_WIDTH-1:0] dot_pro;
   wire                                       [2*DIN_WIDTH-1:0] dot_pro_sum;
   reg                                        [SUM_STAGE_NUM:0] dout_vld_z;

   `ifdef DSP_MULT_ON
      `USE_DSP
   `endif
   reg unsigned   [WIN_SIZE-1:0][WIN_SIZE-1:0][2*DIN_WIDTH-1:0] dot_pro_mat;

   //defining number of operations for each stage
   genvar g;
   generate
      for (g = 1; g <= SUM_STAGE_NUM; g++) begin: sum_stage
         localparam DOT_PRO_SUMS_NUM = (WIN_SQR >> g) + (WIN_SQR % (1 << g) ? 1 : 0);
         reg unsigned [DOT_PRO_SUMS_NUM-1:0][2*DIN_WIDTH-1:0] dot_pro_sums;
      end: sum_stage
   endgenerate

   assign dot_pro       = dot_pro_mat;
   assign dot_pro_sum   = sum_stage[SUM_STAGE_NUM].dot_pro_sums;
   assign dout_vld      = dout_vld_z[SUM_STAGE_NUM];
   assign dout          = dot_pro_sum[2*DIN_WIDTH-1:FOUT_SHIFT];

   always_ff @(posedge clk or negedge reset_n) begin: filter_pipeline
      if (!reset_n) begin
         {dot_pro_mat, dout_vld_z} <= '0;
         for (int i = 1; i <= SUM_STAGE_NUM; i++) begin
            sum_stage[i].dot_pro_sums <= '0; 
         end
      end else begin
         //filter stage # 0: dot_pro calculation
         for (int i = 0; i < WIN_SIZE; i++) begin
            for (int j = 0; j < WIN_SIZE; j++) begin
               dot_pro_mat[i][j] <= window[i][j] * kernel[i][j];
            end
         end

         //filter stage # 1...SUM_STAGE_NUM: dot_pro_sum calculation
         for (int j = 0, l = 0; j < sum_stage[1].DOT_PRO_SUMS_NUM; j++, l += 2) begin //filter stage # 1
            automatic bit k = (j == (sum_stage[1].DOT_PRO_SUMS_NUM - 1)) && (WIN_SQR % 2);
            sum_stage[1].dot_pro_sums[j] <= k ? dot_pro[l] : dot_pro[l] + dot_pro[l+1];
         end
         
         for (int i = 2; i <= SUM_STAGE_NUM; i++) begin //filter stage # 2...SUM_STAGE_NUM
            for (int j = 0, l = 0; j < sum_stage[i].DOT_PRO_SUMS_NUM; j++, l += 2) begin
               automatic bit k = (j == (sum_stage[i].DOT_PRO_SUMS_NUM - 1)) && (sum_stage[i-1].DOT_PRO_SUMS_NUM % 2);
               sum_stage[i].dot_pro_sums[j] <=
                  k ? sum_stage[i-1].dot_pro_sums[l] : sum_stage[i-1].dot_pro_sums[l] + sum_stage[i-1].dot_pro_sums[l+1];
            end
         end

         //dout_vld delay line
         dout_vld_z[SUM_STAGE_NUM:1]   <= dout_vld_z[SUM_STAGE_NUM-1:0];
         dout_vld_z[0]                 <= win_vld;
      end
   end: filter_pipeline
endmodule: filter2d_core