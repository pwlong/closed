# Makefile stolen in large part from conglomeration of Sammer's examples
# 

all: work build run
 
puresim: export MODE = puresim
puresim:
	make all

veloce: export MODE = veloce
veloce:
	make all
 
work:
	clear
	vlib work.$(MODE)
	vmap work work.$(MODE)
 
#Compile/synthesize the environment
build:
	vlog -sv +define+SDR_32BIT ../tb/top_hvl.sv
ifeq ($(MODE),puresim)             #If mode is puresim, compile everything else
	@echo "************PURESIM MODE******************"
	vlog -sv +define+SDR_32BIT -f filelist_veloce.f
	velhvl -sim $(MODE)
else ifeq ($(MODE), veloce)
	@echo "***********VELOCE MODE********************"
	#velanalyze booth_pkg.sv   #Analyze the package for synthesis
	#velanalyze -extract_hvl_info +define+QUESTA top_tb.sv   #Analyze the HVL for external task calls in BFM
	#velanalyze booth_if.sv    #Analyze the interface for synthesis
	#velanalyze top_hdl.sv     #Analyze the HDL top for synthesis
	#velanalyze booth_fsm.sv   #Analyze the booth DUT for synthesis
	#velcomp -top top_hdl      #Synthesize!
	#velhvl -sim $(MODE)

	velanalyze -extract_hvl_info +define+QUESTA ../tb/top_hvl.sv
	velanalyze ../tb/top_hdl.sv

	velanalyze -f filelist_veloce.f
	velcomp -top top_hdl
	velhvl -sim $(MODE)

else
	@echo"failed to specify a mode"
	exit 1
endif
 
run:
	vsim -c -do "run -all" top_hdl top_hvl #Run all
	mv transcript transcript.$(MODE)       #Record transcript
 
 
clean:
	rm -rf   work*  transcript* modelsim.ini  vsim *.log  veloce.med veloce.wave veloce.map velrunopts.ini
 

