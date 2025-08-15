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

CHAIN=arm-linux-gnueabihf
CFLAGS= -g -O2 -std=gnu99 -Wall -mcpu=cortex-a8 -I${INC}
SFLAGS= -g -Wall -mcpu=cortex-a8 -mfpu=neon -mfloat-abi=hard

INC=inc
BIN=bin
DOC=doc
LIB=lib
SRC=src
SUP=sup

# Agregar en el gitignore que estas dos carpetas no se pushean
LST=lst
OBJ=obj

SRC_FILES_C = ${wildcard ${SRC}/*.c}
OBJ_FILES_C = ${subst ${SRC},${OBJ},${SRC_FILES_C:.c=_c.o}}

SRC_FILES_S = ${wildcard ${SRC}/*.s}
OBJ_FILES_S = ${subst ${SRC},${OBJ},${SRC_FILES_S:.s=_s.o}}

LST_FILES	= ${subst ${SRC},${LST},${SRC_FILES_S:.s=.lst}}
MAP_FILES	= ${subst ${SRC}/,${LST}/mi_,${SRC_FILES_C:.c=.map}}

ROOT_NAME = ${notdir ${shell pwd}}

# Telnet Localhost
PORT=1234

# 	variables para ddd
#directorio donde esta configurado .gdbinit (uno de los dos .gdbinit):
PATHDDD = $(CURDIR)
#ubicacion de .lst desde PATHDDD: (direccion relativa de .elf)
PATHELF = obj

################################################################################
##                                   Rules                                    ##
################################################################################

# archivo -> dependencias
# bin -> elf
# elf -> obj
# obj -> .c .s

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

### /////////////////////////QEMU/////////////////////////
EjecutarQemuParaDebug: GeneracionDeBin
# abre otra terminal y ejecuta .bin
	gnome-terminal -- sh -c "bash -c \"qemu-system-arm -M realview-pb-a8 -m 32M -no-reboot -nographic -monitor telnet:127.0.0.1:$(PORT),server,nowait -S -gdb tcp::2159 -kernel $(BIN)/mi_${ROOT_NAME}.bin  ; exec bash\""
	@echo "Abriendo Maquina Virtual en otra Terminal"
## en terminal actual:
	telnet localhost $(PORT)


### /////////////////////////DDD/////////////////////////
Ejecutarddd: ddd_CrearArchivoHome ddd_CrearArchivoDirectorio
# abre otra terminal y ejecuta ddd para debuggear:
	gnome-terminal -- sh -c "bash -c \" cd ~; cd ${PATHDDD}; ddd --debugger gdb-multiarch ${PATHELF}/mi_${ROOT_NAME}.elf ; exec bash\""

# ---- Creamos archivos necesarios para debuggear con ddd -----
## PATHDDD es el directorio donde vamos a ejecutar ddd
ddd_CrearArchivoHome:
## creamos archivo .gdbinit en home
	cd ~; echo "add-auto-load-safe-path" ${PATHDDD} > .gdbinit;

ddd_CrearArchivoDirectorio:
## creamos archivo .gdbinit en carpeta donde vamos a debuggear
	cd ~; cd ${PATHDDD}; echo "set architecture arm" > .gdbinit; echo "target remote localhost:2159" >> .gdbinit
#NOTA '>>' es para escribir al final del archivo y no sobreescribir archivo

## /////////////////////////COMPILACION/////////////////////////
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

$(OBJ)/%_s.o: $(SRC)/%.s
	@echo ""
	@mkdir -p bin
	@mkdir -p obj
	@mkdir -p lst
	@echo "Ensamblando $<"
	@echo "Ensamblando $@"
	$(CHAIN)-as $< ${SFLAGS} -o $@ -a > $(basename $@).lst
	
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
