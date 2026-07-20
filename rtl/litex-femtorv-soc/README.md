# Litex module to generate micro SPI driver using LiteX and FemtoRV core

```bash
uv run litex_soc_gen --cpu-type=femtorv --cpu-variant=electron --name "uspi_driver" 
```

```bash
uv run python -m litex_boards.targets.terasic_de10lite --cpu-type=femtorv --cpu-variant=electron --build
```
