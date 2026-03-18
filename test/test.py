# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

# modified for the LFSR / SISO
# by Yann Guidon / 2026

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# I/O bits and constants:
CLK_SEL     =   1  # assign CLK_SEL   = ui_in[0]; (0 is internal, 1 is EXT_CLK)
EXT_CLK     =   2  # assign EXT_CLK   = ui_in[1];
EXT_RST     =   4  # assign EXT_RST   = ui_in[2]; (extra reset, pull-up if you want continuous operation)
D_IN        =   8  # assign D_IN      = ui_in[3]; (serial data in, from external source)
#              16  # assign           = ui_in[4]; unused
SHOW_LFSR   =  32  # assign SHOW_LFSR = ui_in[5]; (display the LFSR on uio_out if 1, otherwise show the Johnson counter pulses if 0)
LFSR_EN     =  64  # assign LFSR_EN   = ui_in[6]; (set to 1 before reset to allow LFSR operation)
DIN_SEL     = 128  # assign DIN_SEL   = ui_in[7]; (loop back the LFSR to the SISO input when 1, otherwise use external input D_IN), 

D_OUT       =   1  # assign uo_out[0] = D_OUT;       # Delayed D_IN
CLK_OUT     =   2  # assign uo_out[1] = CLK_OUT;     # outputs the selected clock, for external check and 'scope trig
Johnson0    =   4  # assign uo_out[2] = Johnson[0];
Johnson1    =   8  # assign uo_out[3] = Johnson[1];  # Johnson counter's internal state.
Johnson2    =  16  # assign uo_out[4] = Johnson[2];  # Not breathtaking but more debut is better debug.
Johnson3    =  32  # assign uo_out[5] = Johnson[3];
LFSR_PERIOD =  64  # assign uo_out[6] = LFSR_PERIOD; # output for external 'scope trigger, every 255 clock pulses
LFSR_BIT    = 128  # assign uo_out[7] = LFSR_BIT;    # LFSR output, to compare with D_OUT on a 'scope

# assign uio_out  = PULSES or LFSR depending on SHOW_LFSR;

EnableAsserts = True

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.uio_in.value = 0  # will not change
    dut.ena.value = 1     # no change either
    dut.rst_n.value = 0   # circuit stopped

    dut.ui_in.value = LFSR_EN + SHOW_LFSR + DIN_SEL # early selection
    # CLK_SEL=0, internal clock selected.
    await ClockCycles(dut.clk, 2)
  
    dut.rst_n.value = 1            # wake up (from inside)
    await ClockCycles(dut.clk, 2)
    dut._log.info("Test project behavior")

    # The real wake-up

    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = EXT_RST + LFSR_EN + SHOW_LFSR + DIN_SEL  # RESET released, it should take one clock to take effect
    await ClockCycles(dut.clk, 1)
    if EnableAsserts:
      assert dut.uio_out.value == 6 # init pattern
    dut._log.info("wake up")

    i = 0
    while (True):   # run baby run
      await ClockCycles(dut.clk, 1)
      i = i+1
      if EnableAsserts:
        assert i < 200
      if dut.uo_out.value[6]:
        dut._log.info("Period 1: " + str(i) + " = " + str(dut.uio_out.value))
        if EnableAsserts:
          assert dut.uio_out.value == 255
          assert i == 193
        break

    i = 0
    while (True):  # one more time ?
      #assert dut.uio_out.value != 0
      await ClockCycles(dut.clk, 1)
      i = i+1
      if EnableAsserts:
        assert i < 260
      if dut.uo_out.value[6]:
        dut._log.info("Period 2: " + str(i) + " = " + str(dut.uio_out.value))
        if EnableAsserts:
          assert dut.uio_out.value == 255
          assert i == 255
        break

    dut.ui_in.value = EXT_RST + SHOW_LFSR + DIN_SEL  # LFSR_EN off, stall the register feedback
    await ClockCycles(dut.clk, 10)
    if EnableAsserts:
      assert dut.uio_out.value == 4 # not 0 since one bit is inverted
  
    dut._log.info(" LFSR OK !")

    await ClockCycles(dut.clk, 400) # let it run for a while to see the LFSR output from the SIO

    if True:
      dut.ui_in.value = DIN_SEL   # EXT_RST asserted, SHOW_LFSR off : restart everything
      await ClockCycles(dut.clk, 3)
      if EnableAsserts:
        assert dut.uio_out.value == 255 # all the pulses must be on during RESET
      dut._log.info(" check.")
    
      dut.ui_in.value = EXT_RST + DIN_SEL  # restart
      await ClockCycles(dut.clk, 1) # 2 cycles before the counter is visible (including the next wait of 1 cycle)

      i = 0
      while (True):  # one last ride.
        await ClockCycles(dut.clk, 1)
        dut._log.info("cycle " + str(i) + " = " + str(dut.uio_out.value))
        if EnableAsserts:
          assert dut.uio_out.value[i] == 1
        i = i+1
        if i >= 8:
          break

      dut._log.info(" Johnson8 OK !")

      # Reset, re-enable LFSR
      dut.ui_in.value =  LFSR_EN + SHOW_LFSR + DIN_SEL
      await ClockCycles(dut.clk, 2)
      dut.ui_in.value =  LFSR_EN + SHOW_LFSR + DIN_SEL + EXT_RST
      await ClockCycles(dut.clk, 2000) # let it run for a while to see the LFSR output from the SIO
