#!/usr/bin/env python3

# la_soc.py – LiteScope + UART bridge with probe0..probe7 of different widths

from litex.build.sim.platform import SimPlatform
from migen import *
from litex.build.generic_platform import *

from litex.build.generic_platform import GenericPlatform
from litex.build.io import CRG

from litescope import LiteScopeAnalyzer
from litex.soc.cores.uart import UARTWishboneBridge

from litex.soc.integration.soc_core import SoCCore
from litex.soc.integration.builder import Builder

# ----------------------------------------------------------------------
# 1. Virtual platform with named probes of different sizes
# ----------------------------------------------------------------------
_io = [
    ("clk", 0, Pins(1)),
    ("rst", 0, Pins(1)),

    ("serial", 0,
        Subsignal("tx", Pins(1)),
        Subsignal("rx", Pins(1)),
    ),

    ("probe0", 0, Pins(1)),        # 1-bit
    ("probe1", 0, Pins(1)),
    ("probe2", 0, Pins(8)),        # 8-bit
    ("probe3", 0, Pins(8)),
    ("probe4", 0, Pins(32)),       # 32-bit
    ("probe5", 0, Pins(32)),
    ("probe6", 0, Pins(64)),       # 64-bit
    ("probe7", 0, Pins(64)),
]

class Platform(SimPlatform):
    def __init__(self):
        SimPlatform.__init__(self, device="", io=_io, name="la_standalone")

    # def build(self, *args, **kwargs):
    #     print(f'Generic build with: {args} {kwargs}')

# ----------------------------------------------------------------------
# 2. SoC definition
# ----------------------------------------------------------------------
class LAStandalone(SoCCore):
    def __init__(self, platform, sys_clk_freq=50e6):
        SoCCore.__init__(
            self, 
            platform, 
            sys_clk_freq, 
            cpu_type=None,
            uart_name=None,
            with_uart=False,
            with_uartbone=True
        )

        # Clock and reset
        self.submodules.crg = CRG(
            platform.request("clk"),
            platform.request("rst")
        )

        # Collect all probe signals
        probes = [
            platform.request("probe0"),
            platform.request("probe1"),
            platform.request("probe2"),
            platform.request("probe3"),
            platform.request("probe4"),
            platform.request("probe5"),
            platform.request("probe6"),
            platform.request("probe7"),
        ]

        # Logic analyser – all probes as one group "probes"
        analyzer = LiteScopeAnalyzer(
            groups = probes,
            depth  = 2048,
        )
        self.submodules += analyzer


# ----------------------------------------------------------------------
# 3. Build
# ----------------------------------------------------------------------
def main():
    platform = Platform()
    soc = LAStandalone(platform, sys_clk_freq=50e6)
    builder = Builder(soc,
        output_dir        = "build",
        compile_software  = False,
    )
    builder.build()
    soc.finalize()


if __name__ == "__main__":
    main()
