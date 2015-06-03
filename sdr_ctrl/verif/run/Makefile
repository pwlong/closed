all:
	vlib work
	vmap work work
	@echo
	@echo
	@echo "work libs created"
	@echo
	@echo

veloce: all
	vlog -sv -f filelist_hvl.f
	@echo "done vlog...starting velanalyze"
	velanalyze -sv -f filelist_veloce.f

	velcomp  -top top_hdl
	velhvl -sim veloce
	vsim -c -do "run -all" top_hdl top_hvl

puresim: all
	vlog -sv -f filelist_puresim.f
	velhvl -sim puresim
	vsim -c top_hvl top_hdl -do "run -all"

clean:
	rm -rf   work*  transcript* modelsim.ini  vsim *.log  veloce.med veloce.wave veloce.map velrunopts.ini
