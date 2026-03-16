
/* johnson8.v  by whygee@f-cpu.org
  8-step sequencer using an inverted ring counter,
  aka Johnson counter. 4 DFF, 8 AND (NAND+INV4).
  using raw cells from iHP CMOS PDK

  New version: reset forces all outputs to 1 instead of 0
  area : 10.8864 + 4×54.432 + 8×14.5152 = 344.736
*/

module Johnson8(
  input  wire CLK,
  input  wire RESET,
  output wire [3:0] DFF4,
  output wire [7:0] Decoded8);

  // invert & Boost Reset
  wire rstN;
  (* keep *) sg13g2_inv_4 boost0(.Y(rstN),  .A(RESET));

  // The ring counter
  wire [3:0] J4P, J4N;
  (* keep *) sg13g2_dfrbp_2  DFF_J1(.Q(J4P[0]), .Q_N(J4N[0]), .D(J4N[3]), .RESET_B(RESET), .CLK(CLK));
  (* keep *) sg13g2_dfrbp_2  DFF_J2(.Q(J4P[1]), .Q_N(J4N[1]), .D(J4P[0]), .RESET_B(RESET), .CLK(CLK));
  (* keep *) sg13g2_dfrbp_2  DFF_J3(.Q(J4P[2]), .Q_N(J4N[2]), .D(J4P[1]), .RESET_B(RESET), .CLK(CLK));
  (* keep *) sg13g2_dfrbp_2  DFF_J4(.Q(J4P[3]), .Q_N(J4N[3]), .D(J4P[2]), .RESET_B(RESET), .CLK(CLK));
  assign DFF4 = J4P;

  // The decoder
  wire [7:0] DecN;
  (* keep *) sg13g2_a21o_2 dec0(.Y(Decode[0]), .A1(J4N[3]), .A2(J4N[0]), .B1(rstN));
  (* keep *) sg13g2_a21o_2 dec1(.Y(Decode[1]), .A1(J4P[0]), .A2(J4N[1]), .B1(rstN));
  (* keep *) sg13g2_a21o_2 dec2(.Y(Decode[2]), .A1(J4P[1]), .A2(J4N[2]), .B1(rstN));
  (* keep *) sg13g2_a21o_2 dec3(.Y(Decode[3]), .A1(J4P[2]), .A2(J4N[3]), .B1(rstN));
  (* keep *) sg13g2_a21o_2 dec4(.Y(Decode[4]), .A1(J4P[3]), .A2(J4P[0]), .B1(rstN));
  (* keep *) sg13g2_a21o_2 dec5(.Y(Decode[5]), .A1(J4N[0]), .A2(J4P[1]), .B1(rstN));
  (* keep *) sg13g2_a21o_2 dec6(.Y(Decode[6]), .A1(J4N[1]), .A2(J4P[2]), .B1(rstN));
  (* keep *) sg13g2_a21o_2 dec7(.Y(Decode[7]), .A1(J4N[2]), .A2(J4P[3]), .B1(rstN));

endmodule
