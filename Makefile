NAKEN_ASM = C:/naken_asm-24/naken_asm
NAKEN_INCLUDE = C:/naken_asm-24/include

PROJECT_FOLDER ?= $(error = You must pass the folder project folder name: make PROJECT_FOLDER=<project_FOLDER_folder_name>)

INCLUDES = -I $(NAKEN_INCLUDE) -I $(PROJECT_FOLDER)

OUTPUT = $(PROJECT_FOLDER)/bin/$(PROJECT_FOLDER).elf

SRC = $(PROJECT_FOLDER)/$(PROJECT_FOLDER).asm

.PHONY: all clean

all: $(OUTPUT)

$(OUTPUT): $(SRC)
	@echo "Compiling $(SRC) to $(OUTPUT)..."
	"$(NAKEN_ASM)" $(INCLUDES) -o $(OUTPUT) -type elf -l $(SRC)

clean:

	@echo "Removing $(OUTPUT)..."
	del /Q $(OUTPUT)
