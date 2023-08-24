# MS_QSPI_XIP_CACHE
AHB-Lite Quad I/O SPI Flash memory controller with support for:
- XiP 
- Nx16 Direct-Mapped Cache
Intended to be used with SoCs that have no on-chip flash memory. 

## Todo:
 - [ ] Add support for WB bus
 - [ ] Support cache configurations other than 16 bytes per line

 ## Performance
The following table shows a typical SoC performance (execution time in msec) using different cache line sizes 
|NUM_LINES   |LINE_SIZE   |stress |hash |chacha  |xtea(256) |aes_sbox    |G. Mean |
|---|---|---|---|---|---|---|---|
|128 |16  |0.208 (4.9x)    |0.707 (8.8x)    |0.277 (7.4x) |0.212 (11.9x)   |0.339 (6.4x)    |7.53|
|64  |16  |0.208 (4.9x)    |0.779 (8.0x)    |0.277 (7.4x) |0.212 (11.9x)   |0.339 (6.4x)    |7.39|
|32  |16  |0.233 (4.4x)    |0.869 (7.2x)    |0.334 (6.2x) |0.212 (11.9x)   |0.339 (6.4x)    |6.83|
|16  |16  |0.410 (2.5x)    |1.259 (5.0x)    |0.436 (4.7x) |0.212 (11.9x)   |0.339 (6.4x)    |5.37|     
|8   |16  |0.692 (1.5x)    |2.217 (2.8x)    |0.951 (2.2x) |0.218 (11.6x)   |0.341 (6.4x)    |3.69|
|4   |16  |0.899 (1.1x)    |4.983 (1.3x)    |1.723 (1.2x) |-               |-               |-
|2   |16  |1.020 (1.0x)    |6.243 (1.0x)    |2.076 (1.0x) |2.527 ( 1.0x)   |2.191 (1.0x)    |1.00|
