# tnx to mamalala
# Changelog
# Changed the variables to include the header file directory
# Added global var for the XTENSA tool root
#
# This make file still needs some work.
#
# Updated for SDK 0.9.2
#
# Output directors to store intermediate compiled files
# relative to the project directory
ROOT		= $(HOME)/esp-open-sdk
BUILD_BASE	= build
FW_BASE		= firmware

# Base directory for the compiler
XTENSA_TOOLS_ROOT ?= $(ROOT)/xtensa-lx106-elf/bin

# base directory of the ESP8266 SDK package, absolute
SDK_BASE	?= $(ROOT)/esp_iot_sdk_v1.4.0

#Esptool.py path and port
ESPTOOL		?= tools/esptool.py
TTY         ?= USB0
ESPPORT		?= /dev/tty$(TTY)
LOG			?= tools/$(TTY).LOG

# name for the target project
TARGET		= app

# which modules (subdirectories) of the project to include in compiling
MODULES		= driver user cpp mqtt deca wifi actors
EXTRA_INCDIR    = include $(ROOT)/include/ cpp ../Common/inc

# libraries used in this project, mainly provided by the SDK
LIBS		= Common c gcc hal phy net80211 lwip wpa upgrade ssl main pp 

# compiler flags using during compilation of source files
DEFINES		= -D__ESP8266__ -DSTA_SSID=\"Merckx\" -DSTA_PASS=\"LievenMarletteEwoutRonald\"
CFLAGS		= -Os -g -O3 -Wpointer-arith -Wundef -Werror -Wl,-EL -fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals  -D__ets__ -DICACHE_FLASH
CXXFLAGS	= $(CFLAGS) -fno-rtti -fno-exceptions

# linker flags used to generate the main object file
LDFLAGS		= -nostdlib -Wl,--no-check-sections -u call_user_start -Wl,-static -L../Common/Debug -lCommon -Wl,--gc-sections

# linker script used for the above linkier step
LD_SCRIPT	= -Tld/link.ld # eagle.app.v6.ld
# LD_SCRIPT	:= $(addprefix -T$(SDK_BASE)/$(SDK_LDDIR)/,$(LD_SCRIPT))

# various paths from the SDK used in this project
SDK_LIBDIR	= lib
SDK_LDDIR	= ld
SDK_INCDIR	= include include/json

# we create two different files for uploading into the flash
# these are the names and options to generate them
FW_FILE_1	= 0x00000
FW_FILE_1_ARGS	= -bo $@ -bs .text -bs .data -bs .rodata -bc -ec
FW_FILE_2	= 0x40000
FW_FILE_2_ARGS	= -es .irom0.text $@ -ec

# select which tools to use as compiler, librarian and linker
CC		:= $(XTENSA_TOOLS_ROOT)/xtensa-lx106-elf-gcc
CXX		:= $(XTENSA_TOOLS_ROOT)/xtensa-lx106-elf-g++
AR		:= $(XTENSA_TOOLS_ROOT)/xtensa-lx106-elf-ar
LD		:= $(XTENSA_TOOLS_ROOT)/xtensa-lx106-elf-gcc



####
#### no user configurable options below here
####
FW_TOOL		?= /usr/bin/esptool
SRC_DIR		:= $(MODULES)
BUILD_DIR	:= $(addprefix $(BUILD_BASE)/,$(MODULES))

SDK_LIBDIR	:= $(addprefix $(SDK_BASE)/,$(SDK_LIBDIR))
SDK_INCDIR	:= $(addprefix -I$(SDK_BASE)/,$(SDK_INCDIR))

SRC		:= $(foreach sdir,$(SRC_DIR),$(wildcard $(sdir)/*.c*))
C_OBJ		:= $(patsubst %.c,%.o,$(SRC))
CXX_OBJ		:= $(patsubst %.cpp,%.o,$(C_OBJ))
OBJ		:= $(patsubst %.o,$(BUILD_BASE)/%.o,$(CXX_OBJ))
LIBS		:= $(addprefix -l,$(LIBS))
APP_AR		:= $(addprefix $(BUILD_BASE)/,$(TARGET)_app.a)
TARGET_OUT	:= $(addprefix $(BUILD_BASE)/,$(TARGET).out)



INCDIR	:= $(addprefix -I,$(SRC_DIR))
EXTRA_INCDIR	:= $(addprefix -I,$(EXTRA_INCDIR))
MODULE_INCDIR	:= $(addsuffix /include,$(INCDIR))

FW_FILE_1	:= $(addprefix $(FW_BASE)/,$(FW_FILE_1).bin)
FW_FILE_2	:= $(addprefix $(FW_BASE)/,$(FW_FILE_2).bin)

V ?= $(VERBOSE)
ifeq ("$(V)","1")
Q :=
vecho := @true
else
Q := @
vecho := @echo
endif

vpath %.c $(SRC_DIR)
vpath %.cpp $(SRC_DIR)

define compile-objects
$1/%.o: %.c
	$(vecho) "CC $$<"
	$(Q) $(CC) $(INCDIR) $(MODULE_INCDIR) $(EXTRA_INCDIR) $(SDK_INCDIR) $(CFLAGS) $(DEFINES)  -c $$< -o $$@
$1/%.o: %.cpp
	$(vecho) "C+ $$<"
	$(Q) $(CXX) $(INCDIR) $(MODULE_INCDIR) $(EXTRA_INCDIR) $(SDK_INCDIR) $(CXXFLAGS) $(DEFINES) -c $$< -o $$@
endef

.PHONY: all checkdirs clean

all: checkdirs $(TARGET_OUT) $(FLASH)

$(FW_FILE_1): $(TARGET_OUT)
	$(vecho) "FW $@"
	$(Q) $(FW_TOOL) -eo $(TARGET_OUT) $(FW_FILE_1_ARGS)

$(FW_FILE_2): $(TARGET_OUT)
	$(vecho) "FW $@"
	$(Q) $(FW_TOOL) -eo $(TARGET_OUT) $(FW_FILE_2_ARGS)

$(TARGET_OUT): $(OBJ)
	$(vecho) "LD $@"
	$(Q) $(LD) -L$(SDK_LIBDIR) $(LD_SCRIPT) $(LDFLAGS) -Wl,--start-group $(LIBS) $(OBJ) -Wl,--end-group -o $@

$(APP_AR): $(OBJ)
	$(vecho) "AR $@"
	$(Q) $(AR) cru $@ $^

checkdirs: $(BUILD_DIR) $(FW_BASE)

$(BUILD_DIR):
	$(Q) mkdir -p $@

firmware:
	$(Q) mkdir -p $@

flash: $(FW_FILE_1) $(FW_FILE_2)
	-$(ESPTOOL) --port $(ESPPORT) write_flash 0x00000 firmware/0x00000.bin
	sleep 3
	-$(ESPTOOL) --port $(ESPPORT) write_flash 0x40000 firmware/0x40000.bin

FLASH: $(TARGET_OUT)
	tools/reset $(ESPPORT)
	tools/esptool.py --port $(ESPPORT)  read_mac
	tools/esptool.py --port $(ESPPORT)  read_flash  0x3F8000 0x100 dump.bin 
	od --endian=little -X -c dump.bin > $(LOG)
# ../tools/esptool.py --port $TTY  erase_flash
	tools/esptool.py elf2image $(TARGET_OUT)
	tools/esptool2 -debug -bin -boot2 -1024 -dio -40  $(TARGET_OUT) $(TARGET_OUT).bin .text .data .rodata # was 4096
	tools/esptool.py --p $(ESPPORT) -b 576000 write_flash  -ff 40m -fm dio -fs 32m \
		0x00000 tools/rboot.bin \
		0x02000 $(TARGET_OUT).bin  \
		0x3FC000 tools/esp_init_data_default.bin \
		0x3FE000 tools/blank.bin  
	tools/reset $(ESPPORT)
	minicom  -D $(ESPPORT) -C $(LOG)

clean:
	$(Q) rm -f $(APP_AR)
	$(Q) rm -f $(TARGET_OUT)
	$(Q) rm -rf $(BUILD_DIR)
	$(Q) rm -rf $(BUILD_BASE)
	$(Q) rm -f $(FW_FILE_1)
	$(Q) rm -f $(FW_FILE_2)
	$(Q) rm -rf $(FW_BASE)

$(foreach bdir,$(BUILD_DIR),$(eval $(call compile-objects,$(bdir))))
