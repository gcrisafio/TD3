.global _Copia_ROM_a_RAM

.extern _PUBLIC_LMA_SECTION_DATA
.extern _PUBLIC_VMA_SECTION_DATA

.extern _PUBLIC_SIZE_TEXT
.extern _PUBLIC_SIZE_DATA

.section .inicio,"ax"@progbits

_Copia_ROM_a_RAM: 

.arm

_Inicializar_Stack:
      LDR R13, =fin_pila      // Inicializar puntero SP de pila. 

_Copia_Seccion_TEXT: 
      // Copiamos .text (codigo) de LMA a VMA
      LDR R0, =_PUBLIC_RAM_INIT    // Destino
      LDR R1, =_SECTION_TEXT_LMA   // Origen
      LDR R2, =_PUBLIC_SIZE_TEXT   // Cantidad de bytes 
      BL _loop_copy

_Copia_Seccion_DATA:
      // Copiamos .data de LMA a VMA
      LDR R0, =_PUBLIC_VMA_SECTION_DATA     //Destino
      LDR R1, =_PUBLIC_LMA_SECTION_DATA     //origen
      LDR R2, =_PUBLIC_SIZE_DATA            //Cantidad de bytes
      BL _loop_copy

_Bootloader:
      B _prueba_stack // salto a copia en RAM
      WFI

###### Copia de ROM a RAM ######
#     R0 = Destino
#     R1 = Origen
#     R2 = Tamaño
_loop_copy:
    LDRB R3, [R1]
    STRB R3, [R0]
    ADD R0, R0, #1
    ADD R1, R1, #1
    SUBS R2, R2, #1
    BNE _loop_copy
    MOV PC, LR

.section .text_Bootloader,"ax"@progbits          // Sección de codigo.
.arm
_Prueba:       ##Bootloader    // Símbolo que le indica al linker
                              //  donde arranca el programa.
      MOV R1, #1              
      LDR R2, =argumento     
      LDR R0, [R2]

_leer_ascii:
      LDR R12, =asciz_string      // Posicion del string
      LDRB R0, [R12]              // guardar 1er caracter
      LDR R3, =argumento
      STRB R0, [R3]              // poner 1er caracter en argumento

      LDR R0, [R12]              // guardar string
      LDR R3, =factorial
      STR R0, [R3]

_prueba_stack:
      LDR R0, =constante              
      PUSH {R0}
      POP {R0}

      B .

// Seccion de datos inicializados
.section .data
asciz_string:
    .asciz "HOL"

argumento: 
      .word 4            // Argumento del factorial.

constante:
      .word 0xAA55AA55

// Seccion de datos no inicializados
.section .bss            // Sección de datos no inicializados.
factorial: 
      .space 4   // Reservar una palabra para guardar el factorial.

// Seccion de Stack
.section .stack
pila: 
      .space 8192             // Pila de 8KB
fin_pila:
