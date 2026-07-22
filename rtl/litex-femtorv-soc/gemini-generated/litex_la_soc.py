#!/usr/bin/env python3

from migen import *
from litex.build.generic_platform import *
from litex.soc.integration.soc_core import SoCCore
from litex.soc.integration.builder import Builder
from litex.soc.cores.uart import UARTWishboneBridge
from litescope import LiteScopeAnalyzer

# ==============================================================================
# 1. Virtual Platform Definition
# ==============================================================================
# We define a generic abstract platform to map our top-level external pins.
# For multi-bit buses, we explicitly declare string-separated pin arrays so 
# LiteX maps them seamlessly to the Verilog port list.

_io = [
    ("clk", 0, Pins("clk")),
    ("rst", 0, Pins("rst")),
    
    ("uart", 0,
        Subsignal("tx", Pins("uart_tx")),
        Subsignal("rx", Pins("uart_rx")),
    ),
    
    ("probe0", 0, Pins("probe0")),
    ("probe1", 0, Pins("probe1")),
    ("probe2", 0, Pins(" ".join([f"probe2_{i}" for i in range(8)]))),
    ("probe3", 0, Pins(" ".join([f"probe3_{i}" for i in range(8)]))),
    ("probe4", 0, Pins(" ".join([f"probe4_{i}" for i in range(32)]))),
    ("probe5", 0, Pins(" ".join([f"probe5_{i}" for i in range(32)]))),
    ("probe6", 0, Pins(" ".join([f"probe6_{i}" for i in range(64)]))),
    ("probe7", 0, Pins(" ".join([f"probe7_{i}" for i in range(64)]))),
]


class VirtualPlatform(GenericPlatform):
    def __init__(self):
        GenericPlatform.__init__(self, "", _io, name="virtual_analyzer")


# ==============================================================================
# 2. Virtual Analyzer SoC Design
# ==============================================================================
class VirtualAnalyzerSoC(SoCCore):
    def __init__(self, platform):
        # Define an arbitrary clock frequency for the internal UART baudrate generators
        sys_clk_freq = int(100e6) 
        
        # Initialize a minimal, CPU-less SoC configuration
        SoCCore.__init__(self, platform, 
            clk_freq                 = sys_clk_freq,
            cpu_type                 = None, 
            integrated_rom_size      = 0, 
            integrated_sram_size     = 0,
            integrated_main_ram_size = 0,
            csr_data_width           = 32,
            with_uart=False
        )
        
        # Connect top-level clk and rst pins directly to the system clock domain
        self.clock_domains.cd_sys = ClockDomain()
        self.comb += self.cd_sys.clk.eq(platform.request("clk"))
        self.comb += self.cd_sys.rst.eq(platform.request("rst"))
        
        # Instantiate the UART-to-Wishbone bridge to allow control over the Wishbone fabric
        uart_pins = platform.request("uart")
        self.submodules.uart_bridge = UARTWishboneBridge(uart_pins, sys_clk_freq, baudrate=115200)
        self.bus.add_master(name="uart_bridge", master=self.uart_bridge.wishbone)
        
        # Gather all requested probe signals from our abstract platform
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
        
        # Instantiate LiteScope Analyzer and automatically attach its CSRs to the SoC fabric
        # depth=1024 denotes how many sample entries are kept in the internal SRAM buffer.
        self.submodules.analyzer = LiteScopeAnalyzer(probes, 
            depth        = 1024, 
            clock_domain = "sys", 
            register     = True
        )

# ==============================================================================
# 3. Build & Execution Entrypoint
# ==============================================================================
if __name__ == "__main__":
    platform = VirtualPlatform()
    soc      = VirtualAnalyzerSoC(platform)
    
    # Configure builder; compile_gateware=False instructs it to output Verilog source only
    # builder  = Builder(soc, output_dir="litex_la_build", compile_gateware=False, csr_csv="analyzer.csv")
    # builder.build()
    builder  = Builder(soc, output_dir="build", compile_gateware=True)
    builder.build()
