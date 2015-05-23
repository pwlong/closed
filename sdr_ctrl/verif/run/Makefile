# Makefile stolen in large part from conglomeration of Sammer's examples
#  
puresim: export MODE = puresim
puresim:
	$(MAKE) all

veloce: export MODE = veloce
veloce:
	$(MAKE) all
 
all: work build run

 
work:
	clear
	vlib work.$(MODE)
	vmap work work.$(MODE)
 
#Compile/synthesize the environment
build:
        #vlog booth_pkg.sv         #Compile the package
        #vlog top_tb.sv            #Compile the testbench
ifeq ($(MODE),puresim)            #If mode is puresim, compile everything else
	@echo "************PURESIM MODE******************"
        #vlog booth_if.sv          #Compile the interface
        #vlog booth_fsm.sv         #Compile the booth DUT
        #vlog top_hdl.sv           #Compule the HDL top
        #velhvl -sim $(MODE)
	vlog -sv +define+SDR_32BIT -f filelist_emul.f
	#velhvl -sim $(MODE)
else ifeq ($(MODE), veloce)
	@echo "***********VELOCE MODE********************"
	velanalyze booth_pkg.sv   #Analyze the package for synthesis
	velanalyze -extract_hvl_info +define+QUESTA top_tb.sv   #Analyze the HVL for external task calls in BFM
	velanalyze booth_if.sv    #Analyze the interface for synthesis
	velanalyze top_hdl.sv     #Analyze the HDL top for synthesis
	velanalyze booth_fsm.sv   #Analyze the booth DUT for synthesis
	velcomp -top top_hdl      #Synthesize!
	velhvl -sim $(MODE)
else
	@echo"failed to specify a mode"
	exit 1
endif
 
run:
	vsim -c -do "run -all" top_hdl top_hvl #Run all
	mv transcript transcript.$(MODE)       #Record transcript
 
norun:  #No run lets you control stepping etc.
	vsim -c +tbxrun+norun top_tb top_hdl -cpppath $(CPP_PATH)
	cp transcript transcript.$(MODE)
 
clean:
	rm -rf tbxbindings.h modelsim.ini transcript.veloce transcript.puresim work work.puresim work.veloce transcript *~ vsim.wlf *.log dgs.dbg dmslogdir veloce.med veloce.wave veloce.map velrunopts.ini edsenv
 

