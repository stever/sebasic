TARGET=opense.rom

# Project sub-directories that need to be built
SUBDIRS=

# Linker script (config)
LDSCRIPT=opense.ld

# Library, link and include directories
LIB_DIRS  =
LINK_LIBS =
INC_DIRS  = data

# COFF sections to output into target
OUTSECTIONS= .text

# Parameter files that get processed first
PARAMFILES= opense.def

# Define file ending for src files (defaults to z8s)
SRC_EXT=asm

# Source files
Z80_ASM =  \
opense.asm

# Local Makefile Targets
all: dirs $(TARGET) map
	@echo "Done."

fresh: clean all

dirs : 
	@for i in $(SUBDIRS); do \
	(cd $$i; echo "Info: Make $$i"; $(MAKE) $(MFLAGS) $(MYMAKEFLAGS) all); done

map :
	@rm -f $(SNAPSHOT)
	@( \
	    S=`grep __"start_of_startup__ = ." lst/*.map | cut -b 17-35`; \
	    X=`grep __"start_of_startup__ = ." lst/*.map | cut -b 17-35` ; \
	    E=`grep __"bss_end__ = ." lst/*.map | cut -b 17-35` ; \
	    echo "Start Addr is " $$S; \
	    echo "Exec  Addr is " $$X; \
	    echo "End   Addr is " $$E; \
	)

dump: opense.coff
	$(OBJDUMP) -s $?

#  These shouldn't need to be changed
#
#
ifneq ($(strip $(CROSSASM)),)
	export Z80BASE=$(CROSSASM)/z80/tools/bin/
endif

export AS=$(Z80BASE)z80-unknown-coff-as
export AR=$(Z80BASE)z80-unknown-coff-ar
export LD=$(Z80BASE)z80-unknown-coff-ld
export OBJCOPY=$(Z80BASE)z80-unknown-coff-objcopy
export OBJDUMP=$(Z80BASE)z80-unknown-coff-objdump

export ASFLAGS += -z80 -ignore-undocumented-instructions -warn-unportable-instructions

# --oformat forces coff output, as small single file programs seem to generate
# binary output directly, which is not what we want
export LDFLAGS = --trace --oformat coff-z80

ifneq ($(strip $(LDSCRIPT)),)
    LDFLAGS += -T $(LDSCRIPT)
endif

ifneq ($(strip $(OUTSECTIONS)),)
    COPYSECTIONS = $(addprefix -j,$(OUTSECTIONS))
endif

export ROOT=$(shell pwd)

# Define the extension for src files
ifneq ($(strip $(SRC_EXT)),)
    SRCEXT = $(SRC_EXT)
else
    SRCEXT = z80
endif

BIN=rom
OBJ=obj
LST=lst

COFF=$(TARGET:%.rom=%.coff)

OBJF     = $(Z80_ASM:%.$(SRCEXT)=%.o)
OBJFILES = $(addprefix $(OBJ)/,$(OBJF))
LDLIBS   = $(addprefix -l,$(LINK_LIBS))
LDLIBSDIR= $(addprefix -L,$(LIB_DIRS))
INCDIRS  = $(addprefix -I,$(INC_DIRS))

ASFLAGS += $(INCDIRS)

$(TARGET) : bdirs binary
$(LIBRARY): bdirs library

# Build target.coff from target.rom through objcopy
binary: $(COFF)
	@echo Info: Extract sections $(OUTSECTIONS) "-->" $(TARGET)
	@$(OBJCOPY) -v $(OBJCOPYFLAGS) $(COPYSECTIONS) -O binary $< $(TARGET)
	@chmod +x $(TARGET)
	@echo

libf:
	@echo $(OBJFILES)

# Produce library archive from OBJFILES
library: $(OBJFILES)
	@echo Info: Creating library $@
	@rm -f $(LIBRARY)
	@$(AR) -rsv $(LIBRARY) $(OBJFILES)
	@echo

# Assemble .z8s into .o
$(OBJ)/%.o: %.$(SRCEXT)
	@echo "Info: Assemble" $@ "<--" $<
	@$(AS) $(ASFLAGS) -al=$(LST)/$(<:%.$(SRCEXT)=%.lst) -o$@ $(PARAMFILES) $<

# Produce .coff by assembling Z80_ASM into a single .o and then linking with libraries
%.coff : $(Z80_ASM)
	@echo "info: Assemble" $(@:%.coff=%.o) "<--" $?
	$(AS) $(ASFLAGS) -al=$(LST)/$(@:%.coff=%.lst) -o$(OBJ)/$(@:%.coff=%.o) $(PARAMFILES) $?
	@echo
	@echo "Info: Link    " $(@:%.coff=%.o) "-->" $@
	$(LD) $(LDFLAGS) -Map=$(LST)/$(@:%.coff=%.map) -o$@ $(OBJ)/$(@:%.coff=%.o) $(LDLIBSDIR) $(LDLIBS)
	@echo
	@echo Info: Create object dump $(@:%.coff=%.dump)
	@$(OBJDUMP) -d -S $(COPYSECTIONS) $@ > $(LST)/$(@:%.coff=%.dump)

# Link .coff from individual .o files
%.coff_needs_globl : $(OBJFILES)
	@echo "Info: Link " $? "-->" $@
	$(LD) $(LDFLAGS) -Map=$(LST)/$(@:%.coff=%.map) -o$@ $? $(LDLIBSDIR) $(LDLIBS)
	@echo
	@echo Info: Create object dump $(@:%.coff=%.dump)
	@$(OBJDUMP) -d -S $(COPYSECTIONS) $@ > $(LST)/$(@:%.coff=%.dump)

#  Utility targets
bdirs:
	@#[ -d $(BIN) ] || mkdir $(BIN)
	@[ -d $(OBJ) ] || mkdir $(OBJ)
	@[ -d $(LST) ] || mkdir $(LST)

.PHONY: tags
tags :
	@rm -f ctags
	find . -name \*.c -exec ctags -a {} \;
	find . -name \*.h -exec ctags -a {} \;

.PHONEY: gclean
gclean :
	find . -name \*.o -exec rm -f {} \;
	find . -name \*.o._x -exec rm -f {} \;
	find . -name .depend -exec rm -f {} \;
	rm -f $(LST)/*.map $(LST)/*.lst *.coff *.rom $(LST)/*.dump
	rmdir $(LST)
	rmdir $(OBJ)

clean: gclean
