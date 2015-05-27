all:
	vlib work
	vmap work work
	vlog -sv ../../rtl/interfaces/* ../tb/top_hvl.sv | tee ../log/hvl_compile.log

	velanalyze -sv -f filelist_veloce.f |tee ../log/velanalyze.log

	velcomp  -top top_hdl
	vsim -c -do "run -all" top_hdl top_hvl


clean:
	rm -rf   work*  transcript* modelsim.ini  vsim *.log  veloce.med veloce.wave veloce.map velrunopts.ini
