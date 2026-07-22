from migen import *
from litex.soc.integration.soc_core import SoCCore
from litex.soc.integration.builder import Builder
from litex.soc.cores.gpio import GPIOOut
from litex.soc.cores.uart import UART
from litex.build.generic_platform import *
from litex.build.generic_platform import GenericPlatform
from litex.build.tools import write_to_file
from migen.fhdl.verilog import convert


# 1. Define your custom IOs (no physical pin numbers needed)
io = [
    ("clk",   0, Pins("clk")),               # 1-bit input clock
    ("rst",   0, Pins("rst")),               # 1-bit input reset
    ("gpio",  0, Pins("gpio"),  8),          # 8-bit GPIO output
    ("serial",  0,
        Subsignal("tx", Pins("uart_tx")),
        Subsignal("rx", Pins("uart_rx")),
    ),
    ("status",0, Pins("status"), 4),         # extra 4-bit input
]


class DummyToolchain:
    """Minimal toolchain that only writes Verilog and CSR CSV, no synthesis."""
    attr_translate = {}   # required by LiteX toolchain API

    def __init__(self):
        self.build_dir = None
        self.build_name = "top"

    def build_project(self, platform, fragment, build_dir, build_name,
                      **kwargs):
        """Generate Verilog and optional CSR CSV."""
        self.build_dir = build_dir
        self.build_name = build_name

        # Ensure output directory exists
        os.makedirs(build_dir, exist_ok=True)

        # Convert FHDL fragment to Verilog
        v_output = convert(
            fragment,
            ios=platform.get_verilog_ios(),
            name=build_name,
            platform=platform,
            regular_comb=False,          # standard Verilog
            special_overrides=platform.get_special_overrides(),
        )
        v_file = os.path.join(build_dir, build_name + ".v")
        write_to_file(v_file, v_output)
        print(f"Verilog written to {v_file}")

        # Write CSR CSV if CSRs exist
        csr_csv = fragment.get_csr_csv()
        if csr_csv:
            csv_file = os.path.join(build_dir, "csr.csv")
            write_to_file(csv_file, csr_csv)
            print(f"CSR CSV written to {csv_file}")

        # Return the Verilog namespace (used by Builder for CSR headers)
        return fragment.get_verilog()[0]   # (vns, platform) tuple


import os
from migen.fhdl.verilog import convert

class MyCustomPlatform(GenericPlatform):
    """Virtual platform for standalone Verilog IP generation (no physical pins)."""

    def __init__(self, io, default_clk_name=None, default_rst_name=None,
                 default_clk_period=1e9/100e6, **kwargs):
        GenericPlatform.__init__(self, "custom", io, **kwargs)

        # SoC core clock / reset
        self.default_clk_name   = default_clk_name
        self.default_rst_name   = default_rst_name
        self.default_clk_period = default_clk_period

        # No toolchain – we generate files directly
        self.toolchain = None

    def build(self, fragment, build_dir=None, build_name="top", **kwargs):
        """Generate Verilog + CSR CSV, no synthesis."""
        self.finalize(fragment)

        # Convert the SoC FHDL fragment to Verilog
        vns, v_text = convert(
            fragment,
            ios=self.get_verilog(fragment),
            name=build_name,
            platform=self,
            special_overrides=self.get_special_overrides(),
            regular_comb=False,
        )

        # Write Verilog file
        os.makedirs(build_dir, exist_ok=True)
        verilog_path = os.path.join(build_dir, build_name + ".v")
        with open(verilog_path, "w") as f:
            f.write(v_text)
        print(f"[MyCustomPlatform] Verilog written to {verilog_path}")

        # Write CSR CSV if any
        csr_csv = fragment.get_csr_csv()
        if csr_csv:
            csv_path = os.path.join(build_dir, "csr.csv")
            with open(csv_path, "w") as f:
                f.write(csr_csv)
            print(f"[MyCustomPlatform] CSR CSV written to {csv_path}")

        # Return the Verilog namespace (used by Builder for csr.h generation)
        return vns

# class MyCustomPlatform(GenericPlatform):
#     """Virtual platform for standalone Verilog IP generation (no physical pins)."""

#     def __init__(self, io, default_clk_name=None, default_rst_name=None,
#                  default_clk_period=1e9/100e6, **kwargs):
#         GenericPlatform.__init__(self, "custom", io, **kwargs)

#         # SoC core clock / reset
#         self.default_clk_name   = default_clk_name
#         self.default_rst_name   = default_rst_name
#         self.default_clk_period = default_clk_period

#         # Attach dummy toolchain – stops after Verilog generation
#         self.toolchain = DummyToolchain()

    # def build(self, *args, **kwargs):
    #     """Override to handle builder‑passed arguments and skip toolchain."""
    #     # Finalize the platform (resolves constraints, etc.)
    #     # self.finalize(args[0])

    #     # Only generate the top‑level Verilog, no synthesis/P&R
    #     vns = self.toolchain.build_project(args[0], **kwargs)

    #     # Return the Verilog name space (builder uses it for CSR generation)
    #     return vns


# 3. Build a simple SoC on this platform
class CustomSoC(SoCCore):
    def __init__(self, platform, **kwargs):
        # SoCCore automatically connects cpu, bus, rom, sram, uart, timer...
        super().__init__(platform,
            clk_freq=50e6,
            cpu_type=None,
            with_uart=True,
            uart_name='serial',
            **kwargs)

        # Add user peripherals connected to the named platform resources
        self.submodules.gpio = GPIOOut(platform.request("gpio"))
        # status can be added as a simple input signal, etc.


def main():
    # 2. Create the platform
    platform = MyCustomPlatform(
        io,
        default_clk_name  = "clk",
        default_rst_name  = "rst",
        default_clk_period = 1e9/50e6,           # 50 MHz clock
    )

    # 4. Build and stop after Verilog/CSR generation
    soc = CustomSoC(platform)
    builder = Builder(soc, output_dir="build/custom", compile_software=False)
    builder.build(run=False)   # run=False skips all toolchain steps


if __name__ == "__main__":
    main()
