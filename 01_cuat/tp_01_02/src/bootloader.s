.global _Copia_ROM_a_RAM

.extern _PUBLIC_LMA_SECTION_DATA
.extern _PUBLIC_VMA_SECTION_DATA
.extern _SECTION_APLICACION_LMA

.extern _PUBLIC_SIZE_APLICACION
.extern _PUBLIC_SIZE_DATA

.extern UND_Handler
.extern SVC_Handler
.extern PREF_Handler
.extern ABT_Handler
.extern IRQ_Handler
.extern FIQ_Handler
.extern _reset_vector

.extern _VECTOR_TABLE_VMA
.extern _VECTOR_TABLE_LMA
.extern _PUBLIC_SIZE_VECTOR_TABLE
.extern _APLICACION_VMA
.extern _DATA_VMA

.section .vector_table,"ax"@progbits
_table_start: /* Inicio de table_vector */
    LDR PC, addr__reset_vector /* ISR + 0x0000 */
    LDR PC, addr_UND_Handler   /* ISR + 0x0004 */
    LDR PC, addr_SVC_Handler   /* ISR + 0x0008 */
    LDR PC, addr_PREF_Handler  /* ISR + 0x000c */
    LDR PC, addr_ABT_Handler   /* ISR + 0x0010 */
    NOP /* Reservado */        /* ISR + 0x0014 */
    LDR PC, addr_IRQ_Handler   /* ISR + 0x0018 */
    LDR PC, addr_FIQ_Handler   /* ISR + 0x001c */

addr__reset_vector:  .word _reset_vector
addr_UND_Handler  :  .word UND_Handler  
addr_SVC_Handler  :  .word SVC_Handler  
addr_PREF_Handler :  .word PREF_Handler 
addr_ABT_Handler  :  .word ABT_Handler  
addr_IRQ_Handler  :  .word IRQ_Handler  
addr_FIQ_Handler  :  .word FIQ_Handler 

.section .inicializacion,"ax"@progbits

_Copia_ROM_a_RAM: 

.arm

_Inicializar_Stack:
      LDR R13, =fin_pila      // Inicializar puntero SP de pila. 

_Copia_vector_table:
      LDR R0, =_VECTOR_TABLE_VMA    // Destino
      LDR R1, =_VECTOR_TABLE_LMA   // Origen
      LDR R2, =_PUBLIC_SIZE_VECTOR_TABLE   // Cantidad de bytes 
      BL _loop_copy      

_Copia_Seccion_TEXT: 
      // Copiamos .text (codigo) de LMA a VMA
      LDR R0, =_APLICACION_VMA    // Destino
      LDR R1, =_SECTION_APLICACION_LMA   // Origen
      LDR R2, =_PUBLIC_SIZE_APLICACION   // Cantidad de bytes 
      BL _loop_copy

_Copia_Seccion_DATA:
      // Copiamos .data de LMA a VMA
      LDR R0, =_DATA_VMA     //Destino
      LDR R1, =_PUBLIC_LMA_SECTION_DATA     //origen
      LDR R2, =_PUBLIC_SIZE_DATA            //Cantidad de bytes
      BL _loop_copy

_Bootloader:
      SWI 95
      B _Prueba
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

.section .aplicacion,"ax"@progbits          // Sección de codigo.
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

prueba_bss:
      LDR R0, [R12]              // guardar string
      LDR R3, =factorial
      STR R0, [R3]

_prueba_stack:
      LDR R5,=asciz_string
      LDR R0, =constante              
      PUSH {R0}
      PUSH {R1}
      PUSH {R2}
      B .
      POP {R0}

      B .

// Seccion de datos inicializados
.section .data
asciz_string:
    .asciz "HOL"

.section .data
argumento: 
      .word 4            // Argumento del factorial.

.section .data
constante:
      .word 0xAA55AA55

// Seccion de datos no inicializados
.section .bss            // Sección de datos no inicializados.
factorial: 
      .space 4   // Reservar una palabra para guardar el factorial.

// Seccion de Stack
.section .stack, "ax"@nobits //para que no se genere en binario
pila: 
      .space 8192             // Pila de 8KB
fin_pila:
