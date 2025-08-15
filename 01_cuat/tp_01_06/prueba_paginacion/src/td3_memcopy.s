.global my_string
.global _Copia_ROM_a_RAM

.extern _PUBLIC_LMA_SECTION_INICIO
.extern _PUBLIC_VMA_SECTION_INICIO
.extern _PUBLIC_LMA_SECTION_TEXT
.extern _PUBLIC_VMA_SECTION_TEXT
.extern _PUBLIC_LMA_SECTION_DATA
.extern _PUBLIC_VMA_SECTION_DATA
.extern _ROM_ORIGEN

.extern _PUBLIC_SIZE_INICIO
.extern _PUBLIC_SIZE_TEXT
.extern _PUBLIC_SIZE_DATA

.extern td3_memcopy
.extern _start

.section .inicio

_Copia_ROM_a_RAM: 

.arm

_Inicializar_Stack:
      LDR R13, =fin_pila      // Inicializar puntero SP de pila. 

_Copia_Seccion_TEXT:
      // Copiamos .text (codigo) de LMA a VMA
      LDR R0, =_PUBLIC_RAM_INIT    // Destino
      LDR R1, =_SECTION_TEXT_LMA   // Origen
      LDR R2, =_PUBLIC_SIZE_TEXT   // Cantidad de bytes 
      BL td3_memcopy               // Copia de ROM --> RAM 

_Copia_Seccion_DATA:
      // Copiamos .data de LMA a VMA
      LDR R0, =_PUBLIC_VMA_SECTION_DATA     //Destino
      LDR R1, =_PUBLIC_LMA_SECTION_DATA     //origen
      LDR R2, =_PUBLIC_SIZE_DATA            //Cantidad de bytes
      BL td3_memcopy                        // Copia de ROM --> RAM 

_Bootloader:
      B _start // salto a copia en RAM

.section .text_Bootloader          // Sección de codigo.

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
      PUSH {R0}
      POP {R0}

      B .

// Seccion de datos inicializados
.section .data
asciz_string:
    .asciz "HOL"

argumento: .word 4            // Argumento del factorial.


//.ascii "Hola Mundo"      // Sección de datos inicializados.

// Seccion de datos no inicializados
.section .bss            // Sección de datos no inicializados.
factorial: .space 4   // Reservar una palabra para guardar el factorial.

     .section .stack
pila: .space 4096             // Pila de 4KB
fin_pila: