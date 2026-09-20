# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, ReadWrite
from cocotb.handle import Immediate

CONFIG_REGS = 9

async def write_cfg_reg(dut, reg: int, val: int):
    assert reg < 64
    await ReadWrite()
    dut.ui_in.value = ((1 << 7) | reg)
    dut.uio_in.value = val
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0


async def read_cfg_reg(dut, reg: int):
    assert reg < 64
    # await ReadWrite()
    dut.ui_in.value = ((1 << 6) | reg)
    await ClockCycles(dut.clk, 1)
    await ReadWrite()
    dut.ui_in.value = 0
    return dut.uo_out.value

async def read_res(dut, res_idx: int):
    assert res_idx < 64
    # await ReadWrite()
    dut.ui_in.value = ((0 << 6) | res_idx)
    await ClockCycles(dut.clk, 1)
    await ReadWrite()
    dut.ui_in.value = 0
    return dut.uo_out.value


async def test_config_regs(dut):
    vals = [hash(str(i)) & 0x7F for i in range(CONFIG_REGS)]

    for i in range(CONFIG_REGS):
        await write_cfg_reg(dut, i, vals[i])
        tmp = await read_cfg_reg(dut, i)
        assert tmp == vals[i]

    for i in range(CONFIG_REGS):
        tmp = await read_cfg_reg(dut, i)
        assert tmp == vals[i]

async def check_ring_oscillators(dut):
    await write_cfg_reg(dut, 8, 0x1)
    await ReadWrite()
    dut.ui_in.value = ((0 << 6) | 0)
    res = []
    for i in range(100):
        # Our fake-inv/nor gates have a latency of 100 clock cycles (for simulation purposes!)
        await ClockCycles(dut.clk, 4753)
        res.append(int(dut.uo_out.value))
        dut._log.info("rng: %s", str(dut.uo_out.value))
    with open("3-circle.txt", "w") as f:
        f.write(str(res))

async def check_puf(dut):

    cfgs = [[(x + 17 * x*y + 100 + 19* x*x*x + 23 * y*y*y) % 256 for x in range(8)] for y in range(10) ]
    for cfg in cfgs:
        dut._log.info("Cfg: %s", str(cfg))
        for i in range(len(cfg)):
            await write_cfg_reg(dut, i, cfg[i])
        
        tries = 10
        results = [0 for _ in range(8)]
        for _ in range(tries):
            # reset PUF
            await write_cfg_reg(dut, 8, (1 << 6) | (0 << 7))
            await ClockCycles(dut.clk, 10) # Wait for some propagation to happen

            # let PUF settle
            await write_cfg_reg(dut, 8, (0 << 6) | (0 << 7))
            await ClockCycles(dut.clk, 2**10) # Wait a long time for it to settle
            tmp = int(await read_res(dut, 1))
            results = [results[jj] + (1 if (tmp & (1 << jj)) != 0 else 0) for jj in range(8)]
        dut._log.info("Variation: %s", [f"{r}/{tries}" for r in results])

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    # Hold down reset for proper seeding
    await ClockCycles(dut.clk, 100)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

    dut._log.info("Rest registers (read/write)")
    await test_config_regs(dut)

    for i in range(CONFIG_REGS):
        await write_cfg_reg(dut, i, 0)

    # dut._log.info("Test ring oscillators (read/write)")
    # await check_ring_oscillators(dut)


    dut._log.info("Test ring oscillators (read/write)")
    await check_puf(dut)