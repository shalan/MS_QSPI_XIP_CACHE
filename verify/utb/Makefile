SIM-RTL:
	iverilog MS_QSPI_XIP_CACHE_ahbl_tb.v ../../hdl/rtl/MS_QSPI_XIP_CACHE.v ../../hdl/rtl/bus_wrappers/MS_QSPI_XIP_CACHE_ahbl.v ../vip/sst26wf080b.v
	./a.out

SIM-GL:
	iverilog -s MS_QSPI_XIP_CACHE_ahbl_tb MS_QSPI_XIP_CACHE_ahbl_tb.v ../vip/sst26wf080b.v ../../hdl/gl/sky130/MS_QSPI_XIP_CACHE_ahbl.v ../../util/tech/sky130/sky130_hd.v
	./a.out

