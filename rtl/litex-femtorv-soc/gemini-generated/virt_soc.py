import os
from migen import *
from litex.build.generic_platform import GenericPlatform, Pins, Subsignal, IOStandard
from litex.soc.integration.soc_core import SoCCore
from litex.soc.integration.builder import Builder
from litex.soc.interconnect.csr import CSRStorage
from migen.fhdl import verilog

# 1. Define logical I/O definitions for your IP block.
# Because Migen validates pin counts, we use dummy unique strings.
_io = [
    ("clk", 0, Pins("clk_pin")),
    ("rst", 0, Pins("rst_pin")),
    
    # Expose UART so your C program has standard I/O (printf)
    ("serial", 0,
        Subsignal("tx", Pins("serial_tx")),
        Subsignal("rx", Pins("serial_rx")),
    ),
    
    # Custom Interface
    ("custom_bus", 0,
        Subsignal("valid", Pins("valid_pin")),
        Subsignal("ready", Pins("ready_pin")),
        Subsignal("data",  Pins(" ".join(f"data_pin{i}" for i in range(8)))),
    )
]

class MyCustomPlatform(GenericPlatform):
    def __init__(self, io=_io):
        # We initialize with device="standalone" and toolchain="local" to satisfy 
        # the base class without pulling in Vivado/Quartus overhead.
        GenericPlatform.__init__(self, device="standalone_ip", io=io, connectors=[])

    def build(self, fragment, build_dir, build_name, **kwargs):
        """
        Overrides the toolchain build process to strictly output a single Verilog file.
        This prevents vendor scripts (.tcl, .xdc, etc.) from polluting the directory.
        """
        os.makedirs(build_dir, exist_ok=True)
        
        # 1. Save the original working directory
        original_cwd = os.getcwd()
        
        # 2. Change into the target build directory (usually build/gateware)
        os.chdir(build_dir)

        try:
            # Collect top-level I/O signals defined in the platform
            ios = set()
            for sig in self.constraint_manager.get_io_signals():
                ios.add(sig)

            v_output = verilog.convert(fragment, ios, name=build_name)
            
            # 3. Write locally. Because we changed directories, my_custom_ip.v, 
            # rom.init, and sram.init will all safely land in build/gateware/
            v_output.write(f"{build_name}.v")

            # Write Verilog safely to file
            # with open(v_file, "w") as f:
            #     f.write(str(v_output))
    
            # This safely creates my_custom_ip.v AND automatically writes rom.init / sram.init 
            # into the same destination directory.
            # v_output.write(final_v_file)            
        finally:
            # 4. ALWAYS restore the original working directory so the rest of the 
            # LiteX Builder (like software compilation) doesn't break


            os.chdir(original_cwd)
            
        final_v_file = os.path.join(build_dir, f"{build_name}.v")
        print(f"[IP Generator] Standalone Verilog IP written to: {final_v_file}")
        return final_v_file

# -----------------------------------------------------------------------------
# Demonstration: Building a Custom SoC as a Standalone IP
# -----------------------------------------------------------------------------

class CRG(Module):
    """Basic Clock and Reset Generator required by LiteX SoCCore"""
    def __init__(self, clk, rst):
        self.clock_domains.cd_sys = ClockDomain()
        self.comb += [
            self.cd_sys.clk.eq(clk),
            self.cd_sys.rst.eq(rst)
        ]


class StandaloneIP(SoCCore):
    def __init__(self, platform):
        # By setting cpu_type="none", we create a system with CSRs but no CPU processor.
        # This is perfect for hardware accelerators or slave IPs.
        SoCCore.__init__(self, platform,
            clk_freq=int(50e6),

            cpu_type='femtorv',
            cpu_variant='tachyon',
            integrated_rom_size=0x8000,
            integrated_sram_size=0x2000,
            with_uart=True,
            with_timer=True # Included to demonstrate CSR generation

            # cpu_type=None,
            # integrated_rom_size=0,
            # integrated_sram_size=0,
            # integrated_main_ram_size=0,
            # with_uart=False,
            # with_timer=False
        )
        
        # 1. Wire the system clock and reset
        self.submodules.crg = CRG(platform.request("clk"), platform.request("rst"))
        
        # 2. Map our custom interface to the SoC logic
        custom_bus = platform.request("custom_bus")
        
        # 3. Custom Logic: A CSR-addressable register mapped to the top-level 'data' output
        self.custom_data_reg = CSRStorage(8, reset=0xAA, description="Drives custom_bus data port")
        
        self.comb += [
            custom_bus.valid.eq(1),
            custom_bus.data.eq(self.custom_data_reg.storage)
        ]

if __name__ == "__main__":
    platform = MyCustomPlatform()
    soc = StandaloneIP(platform)
    
    # The Builder handles generating the Verilog (via our overridden platform.build)
    # and extracting all the CSR definitions automatically.
    builder = Builder(soc,
        output_dir="build",
        compile_software=True,   # Bypass compiling BIOS/C code
        compile_gateware=True,   # Bypass calling vendor FPGA tools
        csr_csv="build/csr.csv",  # Export CSR definitions in CSV format
        csr_json="build/csr.json" # Export CSR definitions in JSON format
    )
    
    builder.build(build_name="my_custom_ip")
