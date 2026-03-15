/*
 * src/SISO_rs.v (c) 2026 Yann Guidon / whygee@f-cpu.org
 * SPDX-License-Identifier: Apache-2.0
 *
 * This version uses a pair of sg13g2_a21oi_1 to build a transparent latch.
 * This requires 2x the number of wires since bits are complementary.
 * Check the /doc and the diagrams at
 *   https://github.com/ygdes/ttihp-HDSISO8RS/tree/main/docs
 *
 * 4 versions are provided:
 *  - siso_slice4_rs_neg         stores 4 bits in parallel, driven by one inv_4.
 *  - siso_tranche4x4_rs_neg     stores 16 bits (12 effective).
 *  - siso_tranche4x4x4_rs_pos   stores 64 bits, control pulse polarity is back to positive.
 *  - siso_tranche4x4x4x4_rs_pos stores 256 bits, polarity preserved by double inversion.
 *
 * To shift the 4 data bits from siso_in to siso_out, provide 4 sequential,
 * non-overlapping positive pulses on latch[3:0], starting from bit 0 to bit 3.
 * It takes 4 pulses for a new data nibble to appear at the output.
 *
 *  - siso_demux_mux_rs manages the deserialisation and reserialisation of
 * a F/1 bitstream into 8×F/8 bitstreams, using two chains of tranches (odd and even)
 */

//.................................................................................


// Just a 4-bit interter-buffer to keep the code size down.
// area : 4 × 10.9 = 43.6
module Inverters_x4 (
    input  wire [3:0] A,
    output wire [3:0] Y);

  (* keep *) sg13g2_inv_4  Amp0(.Y(Y[0]), .A(A[0]));
  (* keep *) sg13g2_inv_4  Amp1(.Y(Y[1]), .A(A[1]));
  (* keep *) sg13g2_inv_4  Amp2(.Y(Y[2]), .A(A[2]));
  (* keep *) sg13g2_inv_4  Amp3(.Y(Y[3]), .A(A[3]));
endmodule


//.................................................................................

// area : 2 × 9.072 = 18.144
module RSFF_pos(
    input  wire D,
    input  wire D_N,
    input  wire EN,
    output wire Q,
    output wire Q_N);
  (* keep *) sg13g2_a21oi_1 rs_neg(.X(Q_N), .A1(EN), .A2(D  ), .B1(Q  ));
  (* keep *) sg13g2_a21oi_1 rs_pos(.X(Q  ), .A1(EN), .A2(D_N), .B1(Q_N));
endmodule

module RSFF_neg(
    input  wire D,
    input  wire D_N,
    input  wire EN,
    output wire Q,
    output wire Q_N);
  (* keep *) sg13g2_o21ai_1 rs_neg(.Y(Q_N), .A1(EN), .A2(D  ), .B1(Q  ));
  (* keep *) sg13g2_o21ai_1 rs_pos(.Y(Q  ), .A1(EN), .A2(D_N), .B1(Q_N));
endmodule

//.................................................................................

module siso_slice4_rs_neg (        // Pulse low to latch
    input  wire [3:0] siso_in,     // 4 staggered data inputs
    input  wire [3:0] siso_in_N,   // 4 staggered data inputs
    output wire [3:0] siso_out,    // 4 staggered data outputs
    output wire [3:0] siso_out_N,  // 4 staggered data outputs
    input  wire       latch        // pass/keep signal
);

  wire latch_n;
  (* keep *) sg13g2_inv_4 Amp(.Y(latch_n), .A(latch));
  (* keep *) RSFF_pos l0(.Q(siso_out[0]), .Q_N(siso_out_N[0]), .D(siso_in[0]), .D_N(siso_in_N[0]), .EN(latch_n));
  (* keep *) RSFF_pos l1(.Q(siso_out[1]), .Q_N(siso_out_N[1]), .D(siso_in[1]), .D_N(siso_in_N[1]), .EN(latch_n));
  (* keep *) RSFF_pos l2(.Q(siso_out[2]), .Q_N(siso_out_N[2]), .D(siso_in[2]), .D_N(siso_in_N[2]), .EN(latch_n));
  (* keep *) RSFF_pos l3(.Q(siso_out[3]), .Q_N(siso_out_N[3]), .D(siso_in[3]), .D_N(siso_in_N[3]), .EN(latch_n));
endmodule

module siso_slice4_rs_pos (        // Pulse high to latch
    input  wire [3:0] siso_in,     // 4 staggered data inputs
    input  wire [3:0] siso_in_N,   // 4 staggered data inputs
    output wire [3:0] siso_out,    // 4 staggered data outputs
    output wire [3:0] siso_out_N,  // 4 staggered data outputs
    input  wire       latch        // pass/keep signal
);

  wire latch_n;
  (* keep *) sg13g2_inv_4 Amp(.Y(latch_n), .A(latch));
  (* keep *) RSFF_neg l0(.Q(siso_out[0]), .Q_N(siso_out_N[0]), .D(siso_in[0]), .D_N(siso_in_N[0]), .EN(latch_n));
  (* keep *) RSFF_neg l1(.Q(siso_out[1]), .Q_N(siso_out_N[1]), .D(siso_in[1]), .D_N(siso_in_N[1]), .EN(latch_n));
  (* keep *) RSFF_neg l2(.Q(siso_out[2]), .Q_N(siso_out_N[2]), .D(siso_in[2]), .D_N(siso_in_N[2]), .EN(latch_n));
  (* keep *) RSFF_neg l3(.Q(siso_out[3]), .Q_N(siso_out_N[3]), .D(siso_in[3]), .D_N(siso_in_N[3]), .EN(latch_n));
endmodule


//.................................................................................

// Adds 32 latches, 16*2(*3/4) = 24 cycles, + 3DFF => 27 cycles
// but now working as expected (yet)
module siso_demux_mux_dl(
    input  wire       RESET,
    input  wire       CLK,
    input  wire       Din,
    input  wire [7:0] Latch8,
    output wire [3:0] Latch_even,
    output wire [3:0] Latch_odd,
    output wire [3:0] siso_first_even,
    output wire [3:0] siso_first_even_N,
    output wire [3:0] siso_first_odd,
    output wire [3:0] siso_first_odd_N,

    // connect a string of SISO blocks here

    input wire [3:0]  siso_last_even,
    input wire [3:0]  siso_last_even_N,
    input wire [3:0]  siso_last_odd,
    input wire [3:0]  siso_last_odd_N,
    output wire       Dout
);

  wire Even_odd, Deven, Dodd, DevenN, DoddN, FbEven, FbOdd;
  wire [3:0] LEneg, LOneg;
  wire [3:0] te1, te2, te3;
  wire [3:0] to1, to2, to3;
  wire [3:0] exit_even, exit_odd;
  wire Dout_even, Dout_odd, doe1, doe2, doo1, doo2;

  assign Latch_even = { Latch8[6], Latch8[4], Latch8[2], Latch8[0] };
  assign Latch_odd  = { Latch8[7], Latch8[5], Latch8[3], Latch8[1] };

// slowdown 2x at the input
// NOR all bits of Latch_odd:
  (* keep *) sg13g2_nor4_1 Nor_EvenOdd(.Y(Even_odd), .A(Latch8[1]), .B(Latch8[3]), .C(Latch8[5]), .D(Latch8[7]));
  (* keep *) sg13g2_sdfrbp_1 sync_Deven(.Q(FbEven),  .Q_N(DevenN), .D(Din ),  .SCD(FbEven), .SCE(Even_odd), .RESET_B(RESET), .CLK(CLK));
  (* keep *) sg13g2_sdfrbp_1 sync_Dodd (.Q(FbOdd),   .Q_N(DoddN ), .D(FbOdd), .SCD(Din  ),  .SCE(Even_odd), .RESET_B(RESET), .CLK(CLK));

// Boost data pour les triangles d'entrée
  (* keep *) sg13g2_inv_4  Amp_evenN(.Y(Deven), .A(DevenN));
  (* keep *) sg13g2_inv_4  Amp_oddN (.Y(Dodd),  .A(DoddN));

// Le gros du délai : les 2 triangles dans un carré 4×4 chacun (odd+even)
// soit 2 copies modifiées de siso_tranche4x4_dl_neg
//  Inverters_x4 BoostLatchEven(.Y(LEneg), .A(Latch_even));
  siso_slice4_dl_neg slice0e(.siso_in({siso_last_even[3:1], Deven}),     .siso_out(te1),             .latch(Latch_even[3]));
  siso_slice4_dl_neg slice1e(.siso_in({te1[3], te1[2], Deven,  te1[0]}), .siso_out(te2),             .latch(Latch_even[2]));
  siso_slice4_dl_neg slice2e(.siso_in({te2[3], Deven,  te2[1], te2[0]}), .siso_out(te3),             .latch(Latch_even[1]));  // Manquent connexions négatives
  siso_slice4_dl_neg slice3e(.siso_in({Deven,  te3[2], te3[1], te3[0]}), .siso_out(siso_first_even), .latch(Latch_even[0]));

//  Inverters_x4 BoostLatchOdd(.Y(LOneg), .A(Latch_odd));
  siso_slice4_dl_neg slice0o(.siso_in({siso_last_odd [3:1], Dodd}),      .siso_out(to1),             .latch(Latch_odd[3]));
  siso_slice4_dl_neg slice1o(.siso_in({to1[3], to1[2], Dodd,   to1[0]}), .siso_out(to2),             .latch(Latch_odd[2]));
  siso_slice4_dl_neg slice2o(.siso_in({to2[3], Dodd,   to2[1], to2[0]}), .siso_out(to3),             .latch(Latch_odd[1]));
  siso_slice4_dl_neg slice3o(.siso_in({Dodd,   to3[2], to3[1], to3[0]}), .siso_out(siso_first_odd),  .latch(Latch_odd[0]));

// Re-multiplexing

/* version nominale - Sample&Hold maximal, 20 cycles */
  assign exit_even = {te2[2], te3[3], siso_last_even[0], te1[1]}; // This works more or less like a perm matrix
  assign exit_odd  = {to2[2], to3[3], siso_last_odd [0], to1[1]}; // It could get merged below but it might allow
  //  Latch_even[x]     3       2           1              0           some customisation maybe later.

/* version 24 cycles
  assign exit_even = {te3[3], siso_last_even[0], te1[1], te2[2]};
  assign exit_odd  = {to3[3], siso_last_odd [0], to1[1], to2[2]};

  20 cycles ? lower S&H
  assign exit_even = {te1[1], te2[2], te3[3], siso_last_even[0]};
  assign exit_odd  = {to1[1], to2[2], to3[3], siso_last_odd [0]};
*/
  (* keep *) sg13g2_a22oi_1  mux_comb0_even(.Y(doe1), .A1(Latch_even[0]), .A2(exit_even[0]), .B1(Latch_even[1]), .B2(exit_even[1]));
  (* keep *) sg13g2_a22oi_1  mux_comb1_even(.Y(doe2), .A1(Latch_even[2]), .A2(exit_even[2]), .B1(Latch_even[3]), .B2(exit_even[3]));
  (* keep *) sg13g2_nand2_1  mux_nand2_even(.Y(Dout_even), .A(doe1), .B(doe2));

  (* keep *) sg13g2_a22oi_1  mux_comb0_odd( .Y(doo1),  .A1(Latch_odd[0]), .A2(exit_odd[0]),  .B1(Latch_odd[1]), .B2(exit_odd[1]));
  (* keep *) sg13g2_a22oi_1  mux_comb1_odd( .Y(doo2),  .A1(Latch_odd[2]), .A2(exit_odd[2]),  .B1(Latch_odd[3]), .B2(exit_odd[3]));
  (* keep *) sg13g2_nand2_1  mux_nand2_odd( .Y(Dout_odd),  .A(doo1), .B(doo2));

// output selection (odd/even)
  (* keep *) sg13g2_sdfrbpq_1 sync_Dout(.Q(Dout), .D(Dout_odd), .SCD(Dout_even), .SCE(Even_odd), .RESET_B(RESET), .CLK(CLK));
endmodule


/*
//.................................................................................

// area: 4 × 134.1 = 536.4
// 16 latches hold 12 bits
module siso_tranche4x4_dl_neg (  // Pulse low to latch
    input  wire [3:0] siso_in,   // 4 staggered data inputs
    output wire [3:0] siso_out,  // 4 staggered data outputs
    input  wire [3:0] latch      // pass/keep signals
);

  wire [3:0] t1, t2, t3;
  siso_slice4_dl_neg slice0(.siso_in(siso_in), .siso_out(t1),       .latch(latch[3]));
  siso_slice4_dl_neg slice1(.siso_in(t1),      .siso_out(t2),       .latch(latch[2])); // p in reverse order
  siso_slice4_dl_neg slice2(.siso_in(t2),      .siso_out(t3),       .latch(latch[1]));
  siso_slice4_dl_neg slice3(.siso_in(t3),      .siso_out(siso_out), .latch(latch[0]));
endmodule

//.................................................................................

// area: 4×(536.4 + 10.9) = 2189.2
// 64 latches hold 48 bits
module siso_tranche4x4x4_dl_pos ( // Pulse high to latch
    input  wire [3:0] siso_in,    // 4 staggered data inputs
    output wire [3:0] siso_out,   // 4 staggered data outputs
    input  wire [3:0] latch       // pass/keep signals
);

  wire [3:0] t1, t2, t3, p;
  Inverters_x4 Amp(.Y(p), .A(latch));
  siso_tranche4x4_dl_neg tranche0(.siso_in(siso_in), .siso_out(t1),       .latch(p));
  siso_tranche4x4_dl_neg tranche1(.siso_in(t1),      .siso_out(t2),       .latch(p));
  siso_tranche4x4_dl_neg tranche2(.siso_in(t2),      .siso_out(t3),       .latch(p));
  siso_tranche4x4_dl_neg tranche3(.siso_in(t3),      .siso_out(siso_out), .latch(p));
endmodule

//.................................................................................

// area: 5×43.6 + 4×2189.2 = 8974.8
// 256 latches hold 192 bits
module siso_tranche4x4x4x4_dl_pos ( // Pulse high to latch
    input  wire [3:0] siso_in,      // 4 staggered data inputs
    output wire [3:0] siso_out,     // 4 staggered data outputs
    input  wire [3:0] latch         // pass/keep signals
);

  wire [3:0] t1, t2, t3, q, p0, p1, p2, p3;
  // Double inversion, but last stage is per-tranche for better distance/reach
  Inverters_x4  Amp0(.Y(q ), .A(latch));
  Inverters_x4  Amp1(.Y(p0), .A(q));
  Inverters_x4  Amp2(.Y(p1), .A(q));
  Inverters_x4  Amp3(.Y(p2), .A(q));
  Inverters_x4  Amp4(.Y(p3), .A(q));

  siso_tranche4x4x4_dl_pos tranche0(.siso_in(siso_in), .siso_out(t1),       .latch(p0));
  siso_tranche4x4x4_dl_pos tranche1(.siso_in(t1),      .siso_out(t2),       .latch(p1));
  siso_tranche4x4x4_dl_pos tranche2(.siso_in(t2),      .siso_out(t3),       .latch(p2));
  siso_tranche4x4x4_dl_pos tranche3(.siso_in(t3),      .siso_out(siso_out), .latch(p3));
endmodule
*/
