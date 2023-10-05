# MS_QSPI_XIP_CACHE
Quad I/O SPI Flash memory controller with support for:
- AHB lite interface
- Execute in Place (XiP)
- Nx16 Direct-Mapped Cache (default: N=32).
Intended to be used with SoCs that have no on-chip flash memory. 

## Todo:
 - [ ] support for WB bus
 - [ ] Support cache configurations other than 16 bytes per line

## Performance
The following data is obtained using Sky130 HD library
| Configuration | # of Cells (K) | Delay (ns) | I<sub>dyn</sub> (mA/MHz) | I<sub>s</sub> (nA) | 
|---------------|----------------|------------|--------------------------|--------------------|
| 16x16 | 7.2 | 12 | 0.0625 | 20 |
| 32x16 | 14.3 | 17  | 0.126 | 39.5 |
