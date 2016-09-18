//(c) Aleksandr Kotelnikov, al.kotelnikov@gmail.com
package filter2d_pkg;
   parameter FRAME_H          = 1080;
   parameter FRAME_W          = 1920;
   parameter DIN_WIDTH        = 8;
   parameter DOUT_WIDTH       = 10;
   parameter WIN_SIZE         = 3;
   parameter FOUT_SHIFT       = 6;

   parameter logic [WIN_SIZE-1:0][WIN_SIZE-1:0][DIN_WIDTH-1:0] KERNEL = {
      8'd7,    8'd31,   8'd4,
      8'd29,   8'd123,  8'd21,
      8'd5,    8'd35,   8'd1
   };
endpackage: filter2d_pkg
