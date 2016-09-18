(* ORIG_REF_NAME = "builtin_prim" *)
module fifo (
   input    wire       clk,
   input    wire       reset,
   input    wire       wre,
   input    wire [7:0] data_in,
   input    wire       rde,
   output   wire [7:0] data_out
);
   reg  [1:0]  reset_sync;
   wire [23:0] dout_emty;
   wire        rst;

   localparam DATA_WIDTH = 9;

   assign rst = reset_sync[1];

   //UltraScale uses sync reset
   always_ff @(posedge clk) begin: rst_sync
      reset_sync[1] <= reset_sync[0];
      reset_sync[0] <= reset;
   end: rst_sync

   // FIFO18E2: 18Kb FIFO (First-In-First-Out) Block RAM Memory
   // UltraScale
   // Xilinx HDL Libraries Guide, version 2014.1
   
   FIFO18E2 #(
      .CASCADE_ORDER("NONE"), // NONE, FIRST, LAST, MIDDLE, PARALLEL
      .CLOCK_DOMAINS("COMMON"), // INDEPENDENT, COMMON
      .FIRST_WORD_FALL_THROUGH("TRUE"), // FALSE, TRUE
      .INIT(36'h000000000), // Initial values on output port
      .PROG_EMPTY_THRESH(4), // Programmable Empty Threshold
      .PROG_FULL_THRESH(2047), // Programmable Full Threshold
      // Programmable Inversion Attributes: Specifies the use of the built-in programmable inversion
      .IS_RDCLK_INVERTED(1'b0), // Optional inversion for RDCLK
      .IS_RDEN_INVERTED(1'b0), // Optional inversion for RDEN
      .IS_RSTREG_INVERTED(1'b0), // Optional inversion for RSTREG
      .IS_RST_INVERTED(1'b0), // Optional inversion for RST
      .IS_WRCLK_INVERTED(1'b0), // Optional inversion for WRCLK
      .IS_WREN_INVERTED(1'b0), // Optional inversion for WREN
      .RDCOUNT_TYPE("EXTENDED_DATACOUNT"), // RSTREG, REGCE
      .SLEEP_ASYNC("FALSE"), // FALSE, TRUE
      .SRVAL(36'h000000000), // SET/reset value of the FIFO outputs
      .WRCOUNT_TYPE("EXTENDED_DATACOUNT"), // RAW_PNTR, EXTENDED_DATACOUNT, SIMPLE_DATACOUNT, SYNC_PNTR
      .WRITE_WIDTH(DATA_WIDTH) // 4-36
      )
      FIFO18E2_inst (
      // Cascade Signals: 32-bit (each) output: Multi-FIFO cascade signals
      //.CASDOUT(CASDOUT), // 32-bit output: Data cascade output bus
      //.CASDOUTP(CASDOUTP), // 4-bit output: Parity data cascade output bus
      //.CASNXTEMPTY(CASNXTEMPTY), // 1-bit output: Cascade next empty
      //.CASPRVRDEN(CASPRVRDEN), // 1-bit output: Cascade previous read enable
      // Read Data: 32-bit (each) output: Read output data
      .DOUT({dout_emty, data_out}), // 32-bit output: FIFO data output bus
      //.DOUTP(DOUTP), // 4-bit output: FIFO parity output bus.
      // Status: 1-bit (each) output: Flags and other FIFO status outputs
      //.EMPTY(EMPTY), // 1-bit output: Empty
      //.FULL(FULL), // 1-bit output: Full
      //.PROGEMPTY(PROGEMPTY), // 1-bit output: Programmable empty
      //.PROGFULL(PROGFULL), // 1-bit output: Programmable full
      //.RDCOUNT(RDCOUNT), // 13-bit output: Read count
      //.RDERR(RDERR), // 1-bit output: Read error
      //.RDRSTBUSY(RDRSTBUSY), // 1-bit output: Reset busy (sync to RDCLK)
      //.WRCOUNT(WRCOUNT), // 13-bit output: Write count
      //.WRERR(WRERR), // 1-bit output: Write Error
      //.WRRSTBUSY(WRRSTBUSY), // 1-bit output: Reset busy (sync to WRCLK)
      // Cascade Signals: 32-bit (each) input: Multi-FIFO cascade signals
      .CASDIN(32'b0), // 32-bit input: Data cascade input bus
      .CASDINP(4'b0), // 4-bit input: Parity data cascade input bus
      .CASDOMUX(1'b0), // 1-bit input: Cascade MUX select
      .CASDOMUXEN(1'b1), // 1-bit input: Enable for cascade MUX select
      .CASNXTRDEN(1'b0), // 1-bit input: Cascade next read enable
      .CASOREGIMUX(1'b0), // 1-bit input: Cascade output MUX select
      .CASOREGIMUXEN(1'b1), // 1-bit input: Cascade output MUX seelct enable
      .CASPRVEMPTY(1'b0), // 1-bit input: Cascade previous empty
      // Read Control Signals: 1-bit (each) input: Read clock, enable and reset input signals
      .RDCLK(clk), // 1-bit input: Read clock
      .RDEN(rde), // 1-bit input: Read enable
      .REGCE(rde), // 1-bit input: Output register clock enable
      .RSTREG(rst), // 1-bit input: Output register reset
      .SLEEP(1'b0), // 1-bit input: Sleep Mode
      // Write Control Signals: 1-bit (each) input: Write clock and enable input signals
      .RST(rst), // 1-bit input: Reset
      .WRCLK(clk), // 1-bit input: Write clock
      .WREN(wre), // 1-bit input: Write enable
      // Write Data: 32-bit (each) input: Write input data
      .DIN({24'b0, data_in}), // 32-bit input: FIFO data input bus
      .DINP(4'b0) // 4-bit input: FIFO parity input bus
   );
   
   // End of FIFO18E2_inst instantiation
endmodule: fifo