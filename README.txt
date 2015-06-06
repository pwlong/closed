--== To Run our Stuff ==--
cd into:
    sdr_ctr\verif\run
issue:
    make puresim
or issue:
    make veloce

N.B. - make veloce doesn't work.


--== File and Directory Contents ==--

README.md                                       (This is a markdown file used to annotate our GitHub repository)
                                                (https://github.com/pwlong/closed)

SDRAMControllerVerification_Presentation.pdf    (This is a pdf version of the Presentation Slides used in class)

sdr_ctrl\doc                                    (This contains the Micron SDRAM Datasheet)
    \mt48lc2m32b2_sdram.pdf

sdr_ctrl\rtl\core                               (This contains the core IP for the SDRAM Controller - we modified it to use our interfaces)

sdr_ctrl\rtl\interface                          (This contains the interfaces we added to the project - we added this)
    \cfg_if.sv                                      (Interface for the Mode Register values, RAS-to-CAS delays, etc..(
    \sdr_if.sv                                      (Interface between SDRAM Controller and Memory)
    \sdr_pack.sv                                    (Package containing enums)
    \wbinterface.sv                                 (Interface between HVL and HDL)

sdr_ctrl\verif\model
    \mt48lc2m32b2_SYNTH.v                       (This contains a "synthesizable" SDRAM for veloce purposes. Never fully validated)

sdr_ctrl\verif\tb                               (Contains the General test bench code)
    \top.sv
    \top_hvl.sv                                     (The High level Testbench)
    \top_hdl.sv                                     (The Hardware level Testbench)

sdr_ctrl_verif\run                              (CD to this directory, and type 'make puresim' or 'make veloce')
    \Makefile
