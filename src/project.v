/*
 * Copyright (c) 2026 Yann Guidon / whygee@f-cpu.org
 * SPDX-License-Identifier: Apache-2.0
 * Check the /doc and the diagrams at
 *   https://github.com/ygdes/ttihp-HDSISO8RS/tree/main/docs
 * This version uses RS latches based on the A21OI cell.
 */

`default_nettype none

module tt_um_ygdes_hdsiso8_rs (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

////////////////////////////// Plumbing //////////////////////////////

  // IO config & misc.
  assign uio_oe  = 8'b11111111; // port uio goes all out


  // General/housekeeping signals
  wire CLK_SEL, EXT_CLK, EXT_RST;
  assign CLK_SEL   = ui_in[0];
  assign EXT_CLK   = ui_in[1];
  assign EXT_RST   = ui_in[2];
//assign           = ui_in[4]; // unused

  wire CLK_OUT, CLK_OUTn;
  assign uo_out[1] = CLK_OUTn;


  // SISO
  wire D_OUT, D_IN;
  assign D_IN      = ui_in[3];
  assign uo_out[0] = D_OUT;

  // Johnson counter
  wire [3:0] Johnson4;
  assign uo_out[2] = Johnson4[0];
  assign uo_out[3] = Johnson4[1];
  assign uo_out[4] = Johnson4[2];
  assign uo_out[5] = Johnson4[3];


  // LFSR
  wire SHOW_LFSR, LFSR_EN, DIN_SEL;
  assign SHOW_LFSR = ui_in[5];
  assign LFSR_EN   = ui_in[6];
  assign DIN_SEL   = ui_in[7];

  wire LFSR_PERIOD, LFSR_BIT;
  assign uo_out[6] = LFSR_PERIOD;
  assign uo_out[7] = LFSR_BIT;


  // multiplexed output
  // assign uio_out = SHOW_LFSR ? LFSR_state8 : Decoded8 ;
  wire SHOW_LFSR_n1, SHOW_LFSR_n2;
  (* keep *) sg13g2_inv_4 negShow1(.Y(SHOW_LFSR_n1), .A(SHOW_LFSR));
  (* keep *) sg13g2_inv_4 negShow2(.Y(SHOW_LFSR_n2), .A(SHOW_LFSR));
  wire [7:0] LFSR_state8, Decoded8;
  (* keep *) sg13g2_mux2_2 mux_uio0(.A0(LFSR_state8[0]), .A1(Decoded8[0]), .S(SHOW_LFSR_n1), .X(uio_out[0]));
  (* keep *) sg13g2_mux2_2 mux_uio1(.A0(LFSR_state8[1]), .A1(Decoded8[1]), .S(SHOW_LFSR_n1), .X(uio_out[1]));
  (* keep *) sg13g2_mux2_2 mux_uio2(.A0(LFSR_state8[2]), .A1(Decoded8[2]), .S(SHOW_LFSR_n1), .X(uio_out[2]));
  (* keep *) sg13g2_mux2_2 mux_uio3(.A0(LFSR_state8[3]), .A1(Decoded8[3]), .S(SHOW_LFSR_n1), .X(uio_out[3]));
  (* keep *) sg13g2_mux2_2 mux_uio4(.A0(LFSR_state8[4]), .A1(Decoded8[4]), .S(SHOW_LFSR_n2), .X(uio_out[4]));
  (* keep *) sg13g2_mux2_2 mux_uio5(.A0(LFSR_state8[5]), .A1(Decoded8[5]), .S(SHOW_LFSR_n2), .X(uio_out[5]));
  (* keep *) sg13g2_mux2_2 mux_uio6(.A0(LFSR_state8[6]), .A1(Decoded8[6]), .S(SHOW_LFSR_n2), .X(uio_out[6]));
  (* keep *) sg13g2_mux2_2 mux_uio7(.A0(LFSR_state8[7]), .A1(Decoded8[7]), .S(SHOW_LFSR_n2), .X(uio_out[7]));


////////////////////////////// custom soup //////////////////////////////

  // select the clock
  // CLK_OUT = clk if CLK_SEL=0, else EXT_CLK
  // assign CLK_OUT = CLK_SEL ? EXT_CLK : clk;
  (* keep *) sg13g2_mux2_2 mux_clk(.A0(clk), .A1(EXT_CLK), .S(CLK_SEL), .X(CLK_OUT));
  // ring oscillator anyone ?
  (* keep *) sg13g2_inv_4 negClkOut(.Y(CLK_OUTn), .A(CLK_OUT));

  wire INT_RESET;
  // Combined and resynch'ed Reset
  (* keep *) sg13g2_dfrbpq_2 DFF_reset(.Q(INT_RESET), .D(EXT_RST), .RESET_B(rst_n), .CLK(CLK_OUT));


  // Select + resynch D_in
  wire SISO_in;
  //      SISO_in <= DIN_SEL ? LFSR_BIT : D_IN;
  (* keep *) sg13g2_sdfrbpq_1 sync_Din(.Q(SISO_in), .D(D_IN),
                         .SCD(LFSR_BIT), .SCE(DIN_SEL), .RESET_B(INT_RESET), .CLK(CLK_OUT));

////////////////////////////// sub-modules //////////////////////////////

  LFSR8 lfsr(
    .CLK(CLK_OUT),
    .RESET(INT_RESET),
    .LFSR_EN(LFSR_EN),
    .LFSR_PERIOD(LFSR_PERIOD),
    .LFSR_BIT(LFSR_BIT),
    .LFSR_STATE(LFSR_state8));  // the LFSR state is directly routed to the byte output, will be muxed later.

  Johnson8 J8(
    .CLK(CLK_OUT),
    .RESET(INT_RESET),
    .DFF4(Johnson4),
    .Decoded8(Decoded8));

/*
// version : direct loopback, 23 cycles
  wire [3:0] siso_start_even,   siso_start_odd,
             siso_start_even_N, siso_start_odd_N,
             latch4_even, latch4_odd;

  siso_demux_mux_rs demux_mux(
    .RESET(INT_RESET),
    .CLK(CLK_OUT),
    .Din(SISO_in),
    .Latch8(Decoded8),
    .Latch_even(latch4_even),
    .Latch_odd(latch4_odd),
    .siso_first_even(siso_start_even),
    .siso_first_odd(siso_start_odd),
    .siso_last_even(siso_start_even),
    .siso_last_odd(siso_start_odd),
    .siso_first_even_N(siso_start_even_N),
    .siso_first_odd_N(siso_start_odd_N),
    .siso_last_even_N(siso_start_even_N),
    .siso_last_odd_N(siso_start_odd_N),
    .Dout(D_OUT));
*/

// version : 23+24 = 47 cycles
  wire [3:0]  latch4_even, latch4_odd,
    siso_start_even, siso_start_even_N, siso_start_odd, siso_start_odd_N,
    siso_end_even,   siso_end_even_N,   siso_end_odd,   siso_end_odd_N;

  siso_demux_mux_rs demux_mux(
    .RESET(INT_RESET),
    .CLK(CLK_OUT),
    .Din(SISO_in),
    .Latch8(Decoded8),
    .Latch_even(latch4_even),
    .Latch_odd(latch4_odd),
    .siso_first_even(siso_start_even),
    .siso_first_odd(siso_start_odd),
    .siso_last_even(siso_start_even),
    .siso_last_odd(siso_start_odd),
    .siso_first_even_N(siso_end_even_N),
    .siso_first_odd_N(siso_end_odd_N),
    .siso_last_even_N(siso_end_even_N),
    .siso_last_odd_N(siso_end_odd_N),
    .Dout(D_OUT));

// plugging 16*2 latches, or 24 bits
  siso_tranche4x4_rs_pos siso16_1(
    .siso_in(siso_start_even),
    .siso_in_N(siso_start_even_N),
    .siso_out(siso_end_even),
    .siso_out_N(siso_end_even_N),
    .latch(latch4_even));
  siso_tranche4x4_rs_pos siso16_2(
    .siso_in(siso_start_odd),
    .siso_in_N(siso_start_odd_N),
    .siso_out(siso_end_odd),
    .siso_out_N(siso_end_odd_N),
    .latch(latch4_odd));

/*

// version : 23+24+96 = 143 cycles
  wire [3:0]  latch4_even, latch4_odd,
    siso_start_even, siso_start_even_N, siso_start_odd, siso_start_odd_N,
    chain_even,      chain_even_N,      chain_odd,      chain_odd_N,
    siso_end_even,   siso_end_even_N,   siso_end_odd,   siso_end_odd_N;

  siso_demux_mux_rs demux_mux(
    .RESET(INT_RESET),
    .CLK(CLK_OUT),
    .Din(SISO_in),
    .Latch8(Decoded8),
    .Latch_even(latch4_even),
    .Latch_odd(latch4_odd),
    .siso_first_even(siso_start_even),
    .siso_first_odd(siso_start_odd),
    .siso_last_even(siso_start_even),
    .siso_last_odd(siso_start_odd),
    .siso_first_even_N(siso_end_even_N),
    .siso_first_odd_N(siso_end_odd_N),
    .siso_last_even_N(siso_end_even_N),
    .siso_last_odd_N(siso_end_odd_N),
    .Dout(D_OUT));

// plugging 16*2 latches, or 24 bits
  siso_tranche4x4_rs_pos siso16_1(
    .siso_in(siso_start_even),
    .siso_in_N(siso_start_even_N),
    .siso_out(chain_even),
    .siso_out_N(chain_even_N),
    .latch(latch4_even));
  siso_tranche4x4_rs_pos siso16_2(
    .siso_in(siso_start_odd),
    .siso_in_N(siso_start_odd_N),
    .siso_out(chain_odd),
    .siso_out_N(chain_odd_N),
    .latch(latch4_odd));

// plugging 64*2 latches, or 96 bits
  siso_tranche4x4x4_rs_pos siso64_1(
    .siso_in(chain_even),
    .siso_in_N(chain_even_N),
    .siso_out(siso_end_even),
    .siso_out_N(siso_end_even_N),
    .latch(latch4_even));
  siso_tranche4x4x4_rs_pos siso64_2(
    .siso_in(chain_odd),
    .siso_in_N(chain_odd_N),
    .siso_out(siso_end_odd),
    .siso_out_N(siso_end_odd_N),
    .latch(latch4_odd));
*/


/*
//longer version, 384+96+22=502 cycles,
//    about 9 cycles in "advance" of the LFSR period pulse
  wire [3:0] siso_start_even, siso_start_odd;
  wire [3:0] siso_chain_even, siso_chain_odd;
  wire [3:0] latch4_even, latch4_odd;
  wire [3:0] siso_end_even, siso_end_odd;

  siso_demux_mux_rs demux_mux(
    .RESET(INT_RESET),
    .CLK(CLK_OUT),
    .Din(SISO_in),
    .Latch8(Decoded8),
    .Latch_even(latch4_even),
    .Latch_odd(latch4_odd),
    .siso_first_even(siso_start_even),
    .siso_first_odd(siso_start_odd),
    .siso_last_even(siso_end_even),
    .siso_last_odd(siso_end_odd),
    .Dout(D_OUT));

// plugging 256*2 latches, or 384 bits
  siso_tranche4x4x4x4_dl_pos siso256_1(
    .siso_in(siso_start_even),
    .siso_out(siso_chain_even),
    .latch(latch4_even)); // not neg here.
  siso_tranche4x4x4x4_dl_pos siso256_2(
    .siso_in(siso_start_odd),
    .siso_out(siso_chain_odd),
    .latch(latch4_odd)); // not neg here.

// plugging 64*2 latches, or 96 bits
  siso_tranche4x4x4_dl_pos siso64_1(
    .siso_in(siso_chain_even),
    .siso_out(siso_end_even),
    .latch(latch4_even)); // not neg here.
  siso_tranche4x4x4_dl_pos siso64_2(
    .siso_in(siso_chain_odd),
    .siso_out(siso_end_odd),
    .latch(latch4_odd)); // not neg here.
*/

////////////////////////////// All the dummies go here //////////////////////////////

  // List all unused inputs to prevent warnings
  wire _unused = &{
    ena,       // They said not to bother, then ... why provide it ?
    uio_in,
    ui_in[4],
    latch4_even, latch4_odd,
    1'b0};

endmodule
