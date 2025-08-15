# ################################################################################
# #                                                                             #
# #                 Técnicas Digitales 3 - Trabajo Práctico 1                   #
# #                                                                             #
# #@author Crisafio Gabriel
# #@file                                                                        #
# #@brief    Makefile para el Tp1 del primer cuatrimestre.                      #
# #@version                                                                     #
# #@date     2023 v4 (funciona si hay archivos .c y .s)                                                    #
# #                                                                             #
# ################################################################################
# Para compilar el Codigo que prueba las excepciones porer: 
# make EjecutarQemuParaDebug HABILITAR=1

CHAIN=arm-linux-gnueabihf
CFLAGS= -g -O2 -std=gnu99 -Wall -mcpu=cortex-a8 -I${INC}
SFLAGS_BASE= -g -Wall -mcpu=cortex-a8 -mfpu=neon -mfloat-abi=hard
# El SFLAGS final se construye más abajo

INC=inc
BIN=bin
DOC=doc
LIB=lib
SRC=src
SUP=sup

LST=lst
OBJ=obj

SRC_FILES_C = ${wildcard ${SRC}/*.c}
OBJ_FILES_C = ${subst ${SRC},${OBJ},${SRC_FILES_C:.c=_c.o}}

SRC_FILES_S = ${wildcard ${SRC}/*.S}  # usamos .S para preprocesador
OBJ_FILES_S = ${subst ${SRC},${OBJ},${SRC_FILES_S:.S=_s.o}}

LST_FILES	= ${subst ${SRC},${LST},${SRC_FILES_S:.S=.lst}}
MAP_FILES	= ${subst ${SRC}/,${LST}/mi_,${SRC_FILES_C:.c=.map}}

ROOT_NAME = ${notdir ${shell pwd}}

PORT=1234
PATHDDD = $(CURDIR)
PATHELF = obj

################################################################################
##                                   Reglas                                   ##
################################################################################

print:
	@echo ${SRC_FILES_C}
	@echo ${OBJ_FILES_C}
	@echo ${SRC_FILES_S}
	@echo ${OBJ_FILES_S}
	@echo ${LST_FILES}
	@echo ${MAP_FILES}
	@echo ${ROOT_NAME}
	@echo ${NAME}

call: clean all

all: EjecutarQemuParaDebug Ejecutarddd

### ///////////////////////// QEMU /////////////////////////
EjecutarQemuParaDebug: SFLAGS := $(SFLAGS_BASE)
ifeq ($(HABILITAR),1)
EjecutarQemuParaDebug: SFLAGS += -DHABILITAR_PRUEBAS
endif
EjecutarQemuParaDebug: GeneracionDeBin
	gnome-terminal -- sh -c "bash -c \"qemu-system-arm -M realview-pb-a8 -m 1000M -no-reboot -nographic -monitor telnet:127.0.0.1:$(PORT),server,nowait -S -gdb tcp::2159 -kernel $(BIN)/mi_${ROOT_NAME}.bin ; exec bash\""
	@echo "Abriendo Maquina Virtual en otra Terminal"
	telnet localhost $(PORT)

### ///////////////////////// DDD /////////////////////////
Ejecutarddd: ddd_CrearArchivoHome ddd_CrearArchivoDirectorio
	gnome-terminal -- sh -c "bash -c \" cd ~; cd ${PATHDDD}; ddd --debugger gdb-multiarch ${PATHELF}/mi_${ROOT_NAME}.elf ; exec bash\""

ddd_CrearArchivoHome:
	cd ~; echo "add-auto-load-safe-path" ${PATHDDD} > .gdbinit;

ddd_CrearArchivoDirectorio:
	cd ~; cd ${PATHDDD}; echo "set architecture arm" > .gdbinit; echo "target remote localhost:2159" >> .gdbinit

### ///////////////////////// COMPILACIÓN /////////////////////////
GeneracionDeBin: $(BIN)/mi_${ROOT_NAME}.bin $(OBJ)/mi_${ROOT_NAME}.elf

$(BIN)/mi_${ROOT_NAME}.bin: $(OBJ)/mi_${ROOT_NAME}.elf
	$(CHAIN)-objcopy -O binary $< $@

$(OBJ)/mi_${ROOT_NAME}.elf: ${OBJ_FILES_S} ${OBJ_FILES_C}
	@echo "Linkeando..."
	@mkdir -p obj
	@mkdir -p lst
	$(CHAIN)-ld -T td3_memmap.ld ${OBJ_FILES_S} ${OBJ_FILES_C} -o $@ -Map $(LST)/$(ROOT_NAME).map
	@echo "Linkeo finalizado"
	@echo ""
	@echo "Generando archivos de información mapa de memoria y símbolos"
	readelf -a $@ > $(basename $@).txt
	$(CHAIN)-objdump -D $@ > $(basename $@).lst

$(OBJ)/%_s.o: $(SRC)/%.S
	@echo ""
	@mkdir -p bin
	@mkdir -p obj
	@mkdir -p lst
	@echo "Ensamblando $<"
	@echo "Ensamblando $@"
	$(CHAIN)-gcc -c ${SFLAGS} $< -o $@ -Wa,-a > $(basename $@).lst

$(OBJ)/%_c.o: $(SRC)/%.c
	@echo ""
	@mkdir -p bin
	@mkdir -p obj
	@mkdir -p lst
	@echo "Compilando ${SRC_FILES_C} ..."
	$(CHAIN)-gcc ${CFLAGS} -c $< -o $@

-include ${OBJ}/*.d

clean:
	rm -rf $(OBJ)/*.o
	rm -rf $(OBJ)/*.elf
	rm -rf $(OBJ)/*.d
	rm -rf $(OBJ)/*.txt
	rm -rf $(BIN)/*.bin
	rm -rf $(LST)/*.lst
	rm -rf $(LST)/*.txt
	rm -rf $(LST)/*.map

