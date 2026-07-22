#!/usr/bin/env python3
#
# MyCustomPlatform - LiteX Platform for Standalone Verilog IP Generation
#
# This platform generates a clean Verilog module suitable for embedding into
# larger FPGA projects as a standalone IP core. No vendor toolchain is invoked.
#

import os
import sys
from typing import List, Tuple, Optional, Dict, Any

from migen import *
from migen.fhdl.structure import _Fragment

from litex.build.generic_platform import (
    GenericPlatform, Pins, Subsignal, IOStandard, Misc, 
    ConstraintError
)
from litex.build import tools
# from litex.gen.fhdl.verilog import DummyVerilogNamespace


class VerilogOnlyToolchain:
    """
    Dummy toolchain that does nothing. Prevents GenericPlatform from
    trying to invoke a real vendor toolchain.
    """
    attr_translate = {}  # No attribute translation needed for pure Verilog
    
    def __init__(self):
        pass
    
    def build(self, platform, fragment, **kwargs):
        # This should never be called when using our custom flow,
        # but implement it to satisfy the interface.
        raise NotImplementedError(
            "VerilogOnlyToolchain does not support build(). "
            "Use platform.get_verilog() instead."
        )


class MyCustomPlatform(GenericPlatform):
    """
    Custom LiteX platform that accepts arbitrary IO definitions and produces
    only a generated Verilog file + CSR definitions.
    
    No FPGA vendor toolchain is required or invoked. The generated Verilog
    is intended to be embedded into larger FPGA projects as a standalone IP.
    
    Usage:
        platform = MyCustomPlatform(device="xc7a100t", io=my_io_definitions)
        soc = MySoC(platform, ...)
        # Generate Verilog only:
        v_output = platform.get_verilog(soc, name="my_soc")
        platform.save_verilog(v_output, build_dir="build", build_name="my_soc")
    """
    
    # No bitstream extension - we're not generating bitstreams
    bitstream_ext = ".v"
    
    def __init__(self, 
                 device: str = "generic",
                 io: List[Tuple] = None,
                 connectors: List[Tuple] = None,
                 name: str = "litex_soc",
                 **kwargs):
        """
        Initialize the custom platform.
        
        Args:
            device: Device identifier string (informational only, e.g. "xc7a100t")
            io: List of IO definitions using Pins/Subsignal/IOStandard
            connectors: Optional list of connector definitions
            name: Module name for generated Verilog
            **kwargs: Additional arguments passed to GenericPlatform
        """
        self.device = device
        self.name = name
        self._custom_constraints = []  # Store user constraints
        
        # Initialize with empty IO if none provided
        if io is None:
            io = []
        if connectors is None:
            connectors = []
            
        # Call parent init - GenericPlatform expects (device, io, connectors)
        super().__init__(device, io, connectors, **kwargs)
        
        # Replace with dummy toolchain to prevent vendor tool invocation
        self.toolchain = VerilogOnlyToolchain()
    
    # -------------------------------------------------------------------------
    # IO Definition Helpers
    # -------------------------------------------------------------------------
    
    def add_io(self, name: str, index: int, pins, 
               io_standard: str = None, 
               misc: List[str] = None,
               **kwargs) -> None:
        """
        Add a single IO signal to the platform after initialization.
        
        Args:
            name: Signal name (e.g., "uart", "led", "gpio")
            index: Instance index
            pins: Pins() definition or width
            io_standard: IO standard string (e.g., "LVCMOS33")
            misc: Additional constraint strings
        """
        if isinstance(pins, int):
            pins = Pins(pins)
        
        io_def = [name, index, pins]
        
        if io_standard is not None:
            io_def.append(IOStandard(io_standard))
        if misc is not None:
            for m in misc:
                io_def.append(Misc(m))
        
        self.add_extension([tuple(io_def)])
    
    def add_subsignal_io(self, name: str, index: int, 
                         subsignals: List[Tuple[str, Pins]],
                         io_standard: str = None,
                         **kwargs) -> None:
        """
        Add an IO with multiple subsignals (e.g., differential pairs, buses).
        
        Args:
            name: Top-level signal name
            index: Instance index  
            subsignals: List of (subsignal_name, Pins()) tuples
            io_standard: Default IO standard for all subsignals
        """
        subs = []
        for sig_name, sig_pins in subsignals:
            if isinstance(sig_pins, int):
                sig_pins = Pins(sig_pins)
            subs.append(Subsignal(sig_name, sig_pins))
        
        io_def = [name, index] + subs
        
        if io_standard is not None:
            io_def.append(IOStandard(io_standard))
        
        self.add_extension([tuple(io_def)])
    
    # -------------------------------------------------------------------------
    # Clock/Constraint Handling (informational, passed through to Verilog)
    # -------------------------------------------------------------------------
    
    def add_period_constraint(self, platform_request, period: float):
        """
        Add clock period constraint (stored for reference, not enforced).
        
        The constraint is saved and can be exported for use in your
        project's top-level constraints file.
        """
        self._custom_constraints.append({
            'type': 'period',
            'signal': platform_request,
            'period': period,
            'frequency': 1.0/period if period > 0 else 0
        })
        # Also call parent to maintain internal state
        super().add_period_constraint(platform_request, period)
    
    def add_false_path_constraint(self, from_signal, to_signal):
        """Add false path constraint (informational)."""
        self._custom_constraints.append({
            'type': 'false_path',
            'from': from_signal,
            'to': to_signal
        })
        super().add_false_path_constraint(from_signal, to_signal)
    
    def get_constraints_summary(self) -> str:
        """Generate a human-readable summary of all constraints."""
        lines = [f"# Constraints for {self.name}"]
        for c in self._custom_constraints:
            if c['type'] == 'period':
                lines.append(f"# create_clock -period {c['period']*1e9:.3f}ns [{c['signal']}]")
            elif c['type'] == 'false_path':
                lines.append(f"# set_false_path -from [{c['from']}] -to [{c['to']}]")
        return '\n'.join(lines)
    
    # -------------------------------------------------------------------------
    # Verilog Generation (Core Functionality)
    # -------------------------------------------------------------------------
    
    def get_verilog(self, fragment, name=None, **kwargs):
        """
        Generate Verilog from a fragment/SoC.
        
        Overrides GenericPlatform.get_verilog to ensure clean output
        without vendor-specific special overrides.
        
        Args:
            fragment: The SoC/module to convert
            name: Module name (defaults to self.name)
            **kwargs: Passed to migen's verilog converter
        
        Returns:
            Verilog output object with .ns (namespace) attribute
        """
        if name is None:
            name = self.name
            
        # Ensure fragment is resolved
        if not isinstance(fragment, _Fragment):
            fragment = fragment.get_fragment()
        
        # Finalize the design (applies platform commands, constraints)
        self.finalize(fragment)
        
        # Generate pure Verilog without vendor-specific special overrides
        # This is the key: we don't pass special_overrides from any toolchain
        v_output = super().get_verilog(
            fragment,
            name=name,
            special_overrides={},  # Empty - no vendor primitives
            attr_translate={},      # No attribute translation
            create_clock_domains=False,  # Don't auto-create clock domains
            **kwargs
        )
        
        return v_output
    
    def save_verilog(self, v_output, build_dir: str = "build", 
                     build_name: str = None) -> str:
        """
        Save generated Verilog to file and return the path.
        
        Also generates a companion constraints reference file.
        
        Args:
            v_output: Output from get_verilog()
            build_dir: Output directory
            build_name: Base filename (defaults to self.name)
        
        Returns:
            Path to the generated Verilog file
        """
        if build_name is None:
            build_name = self.name
            
        os.makedirs(build_dir, exist_ok=True)
        
        # Write main Verilog file
        v_file = os.path.join(build_dir, f"{build_name}.v")
        tools.write_to_file(v_file, v_output.ns.getvalue())
        
        # Write constraints reference
        if self._custom_constraints:
            xdc_file = os.path.join(build_dir, f"{build_name}_constraints.xdc")
            tools.write_to_file(xdc_file, self.get_constraints_summary())
        
        return v_file
    
    # -------------------------------------------------------------------------
    # CSR Export
    # -------------------------------------------------------------------------
    
    def export_csr(self, soc, build_dir: str = "build", 
                   build_name: str = None,
                   formats: List[str] = None) -> Dict[str, str]:
        """
        Export CSR definitions in multiple formats.
        
        Args:
            soc: The SoC with CSR regions
            build_dir: Output directory
            build_name: Base filename
            formats: List of formats to generate ('h', 'csv', 'json', 'svd')
        
        Returns:
            Dictionary mapping format to output file path
        """
        if build_name is None:
            build_name = self.name
        if formats is None:
            formats = ['h', 'csv', 'json']
            
        os.makedirs(build_dir, exist_ok=True)
        outputs = {}
        
        # Get CSR regions from the SoC
        csr_regions = getattr(soc, 'csr_regions', {})
        constants = getattr(soc, 'constants', {})
        mem_regions = getattr(soc, 'mem_regions', {})
        
        for fmt in formats:
            if fmt == 'h':
                # C header
                from litex.soc.integration.export import get_csr_header
                content = get_csr_header(csr_regions, constants, 
                                        with_access_functions=True)
                ext = ".h"
            
            elif fmt == 'csv':
                # CSV register map
                from litex.soc.integration.export import get_csr_csv
                content = get_csr_csv(csr_regions)
                ext = ".csv"
            
            elif fmt == 'json':
                # JSON for tooling
                from litex.soc.integration.export import get_csr_json
                content = get_csr_json(csr_regions, constants, mem_regions)
                ext = ".json"
            
            elif fmt == 'svd':
                # ARM CMSIS-SVD
                from litex.soc.integration.export import get_csr_svd
                content = get_csr_svd(soc, build_name)
                ext = ".svd"
            
            else:
                continue
                
            path = os.path.join(build_dir, f"{build_name}_csr{ext}")
            tools.write_to_file(path, content)
            outputs[fmt] = path
        
        return outputs
    
    # -------------------------------------------------------------------------
    # Build Override (Prevent Toolchain Invocation)
    # -------------------------------------------------------------------------
    
    def build(self, fragment, **kwargs):
        """
        Override build() to prevent accidental toolchain invocation.
        
        Instead of running a vendor toolchain, this generates Verilog
        and CSRs only.
        """
        build_dir = kwargs.get('build_dir', 'build')
        build_name = kwargs.get('build_name', self.name)
        
        # Generate Verilog
        v_output = self.get_verilog(fragment, name=build_name)
        v_file = self.save_verilog(v_output, build_dir, build_name)
        
        # Try to export CSRs if fragment is an SoC
        csr_files = {}
        if hasattr(fragment, 'csr_regions'):
            csr_files = self.export_csr(fragment, build_dir, build_name)
        
        print(f"[MyCustomPlatform] Generated Verilog: {v_file}")
        for fmt, path in csr_files.items():
            print(f"[MyCustomPlatform] Generated CSR ({fmt}): {path}")
        
        # Return a simple namespace-like object for compatibility
        class BuildResult:
            def __init__(self, ns, files):
                self.ns = ns
                self.generated_files = files
        
        return BuildResult(v_output.ns, {
            'verilog': v_file,
            'csr': csr_files
        })
    
    def create_programmer(self):
        """No programmer - this is a pure Verilog generation platform."""
        raise NotImplementedError(
            "MyCustomPlatform does not support programming. "
            "Use the generated Verilog in your own project."
        )


# =============================================================================
# Example Usage: Complete SoC Target
# =============================================================================

def example_usage():
    """
    Example showing how to use MyCustomPlatform to create a standalone
    Verilog IP module with a simple LiteX SoC.
    """
    from litex.soc.integration.soc_core import SoCCore
    from litex.soc.integration.builder import Builder
    from litex.soc.cores.uart import UARTPHY
    from litex.soc.cores import gpio
    
    # -------------------------------------------------------------------------
    # 1. Define your custom IO
    # -------------------------------------------------------------------------
    
    # Simple example: UART + GPIO LEDs + Clock/Reset
    my_io = [
        # Clock input
        ("clk", 0, Pins(1), IOStandard("LVCMOS33")),
        
        # Active-low reset
        ("rst_n", 0, Pins(1), IOStandard("LVCMOS33")),
        
        # UART
        ("uart", 0,
            Subsignal("tx", Pins(1)),
            Subsignal("rx", Pins(1)),
            IOStandard("LVCMOS33")
        ),
        
        # LEDs (8-bit)
        ("led", 0, Pins(8), IOStandard("LVCMOS33")),
        
        # GPIO (32-bit bidirectional)
        ("gpio", 0, Pins(32), IOStandard("LVCMOS33")),
    ]
    
    # -------------------------------------------------------------------------
    # 2. Create platform
    # -------------------------------------------------------------------------
    
    platform = MyCustomPlatform(
        device="xc7a100t-1csg324",  # Informational only
        io=my_io,
        name="my_custom_soc"
    )
    
    # -------------------------------------------------------------------------
    # 3. Define SoC
    # -------------------------------------------------------------------------
    
    class MySoC(SoCCore):
        def __init__(self, platform, sys_clk_freq=100e6, **kwargs):
            # Create clock domain from external clock
            self.clock_domains.cd_sys = ClockDomain()
            
            # Simple clock/reset connection
            clk = platform.request("clk")
            rst_n = platform.request("rst_n")
            self.comb += [
                self.cd_sys.clk.eq(clk),
                self.cd_sys.rst.eq(~rst_n),  # Active high internally
            ]
            
            # Initialize SoCCore
            SoCCore.__init__(self, platform, sys_clk_freq,
                ident="My Custom LiteX SoC",
                **kwargs)
            
            # Add UART (using standard LiteX UART)
            from litex.soc.cores.uart import UART
            self.submodules.uart = UART(
                pads=platform.request("uart"),
                clk_freq=sys_clk_freq,
                baudrate=115200
            )
            
            # Add GPIO for LEDs
            self.submodules.leds = gpio.GPIOOut(platform.request("led"))
            
            # Add GPIO controller
            self.submodules.gpio = gpio.GPIOTristate(platform.request("gpio"))
    
    # -------------------------------------------------------------------------
    # 4. Build/generate
    # -------------------------------------------------------------------------
    
    soc = MySoC(platform,
        cpu_type="vexriscv",           # Or "serv", "femtorv", or None
        integrated_rom_size=0x8000,    # 32KB ROM
        integrated_sram_size=0x4000,   # 16KB SRAM
        with_uart=False,               # We added our own UART
    )
    
    # Generate Verilog + CSRs (no vendor toolchain invoked!)
    result = platform.build(soc, build_dir="build/custom_soc")
    
    print("\n=== Generation Complete ===")
    print(f"Top module: {platform.name}")
    print(f"Files: {result.generated_files}")
    
    # Or use Builder for more control (software compilation, etc.)
    # builder = Builder(soc, output_dir="build", compile_software=True)
    # builder.build(run=False)  # run=False prevents toolchain invocation


if __name__ == "__main__":
    example_usage()
