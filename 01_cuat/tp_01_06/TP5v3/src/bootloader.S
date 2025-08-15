.global _Bootloader
.global _habilitar_INT

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
.extern move
.extern __gic_init
.extern _start
.extern _paginacion

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
    B PREF_Handler  /* ISR + 0x000c */
    LDR PC, addr_ABT_Handler   /* ISR + 0x0010 */
    NOP /* Reservado */        /* ISR + 0x0014 */
    LDR PC, addr_IRQ_Handler   /* ISR + 0x0018 */
    LDR PC, addr_FIQ_Handler   /* ISR + 0x001c */

/* Se definen las direcciones de los handlers, el compilador va a generar un literal pull LDR PC,[PC, #offset]. 
Esto significa que los 32B del vector de interrupciones deben tener a continuacion las direcciones de los handler para poder hacer un literal pull  */

addr__reset_vector:  .word _reset_vector
addr_UND_Handler  :  .word UND_Handler  
addr_SVC_Handler  :  .word SVC_Handler  
addr_PREF_Handler :  .word PREF_Handler 
addr_ABT_Handler  :  .word ABT_Handler  
addr_IRQ_Handler  :  .word IRQ_Handler  
addr_FIQ_Handler  :  .word FIQ_Handler 

.section .inicializacion,"ax"@progbits
.arm

_Bootloader: 
      BL _start


_Inicializar_Stack_Undefined_Instruction:

_Cambio_a_modo_Undefined_Instruction:
    MRS R0, CPSR
    BIC R0, R0, #0x1F // Borrar los bits CPSR[4:0]
    ORR R0, R0, #0x1B // Escribir CPSR[4:0]=11011=Modo Undefined Instruction
    MSR CPSR_c, R0   

_Inicializar_Stack_de_modo_Undefined_Instruction:
    LDR SP, =fin_pila_undefined_instruction      // Inicializar puntero SP de pila. 

_Cambio_a_modo_Supervisor:
      // vuelvo a modo System
    MRS R0, CPSR
    AND R0, R0, #0xFFFFFFE0  // Borrar los bits CPSR[4:0] = 0 0000
    ORR R0, R0, #0x13 // Escribir CPSR[4:0]=1 0011=Modo Supervisor (SVC)
    MSR CPSR_c, R0 

_Inicializar_Stack_SVC:
      LDR SP, =fin_pila_svc

_Copia_vector_table:
      LDR R0, =_VECTOR_TABLE_LMA   // Origen
      LDR R1, =_VECTOR_TABLE_VMA    // Destino
      LDR R2, =_PUBLIC_SIZE_VECTOR_TABLE   // Cantidad de bytes 
      BL move      

_Copia_Seccion_TEXT: 
      // Copiamos .text (codigo) de LMA a VMA
      LDR R0, =_SECTION_APLICACION_LMA   // Origen
      LDR R1, =_APLICACION_VMA    // Destino
      LDR R2, =_PUBLIC_SIZE_APLICACION   // Cantidad de bytes 
      BL move

_Copia_Seccion_DATA:
      // Copiamos .data de LMA a VMA
      LDR R0, =_PUBLIC_LMA_SECTION_DATA     //origen
      LDR R1, =_DATA_VMA     //Destino
      LDR R2, =_PUBLIC_SIZE_DATA            //Cantidad de bytes
      BL move

      B _habilitar_GIC

.section .text_perifericos,"ax"@progbits

_habilitar_GIC:
      LDR R10, =__gic_init
      MOV LR, PC
      BX R10

_hablitar_TIMER0:
_cargo_valor_10mseg:
      LDR R0, =0x10011000     // Dirección del registro Load
      LDR R1, =10000            // 10000 [useg] = 10 [mseg] 
      STR R1, [R0]            // Escribir 0xA en [0x10011000]

_control_timer:
      LDR R0, =0x10011008     // Dirección del registro de Control
      LDR R1, [R0]            // Leer valor actual del registro de control
      LDR R2, =0b11101100    // Cargar el valor inmediato en R2
      /*  
            bit [7]: 1 -> Habilitacion del modulo TIMER  
            bit [6]: 1 -> Modo Periodico, termina cuenta y recarga valor de LOAD
            bit [5]: 1 -> Habilitar interrupciones del Timer
            bit [4]: 0 -> Reservado, no tocar
            bit [2:3]: 11 -> No usar Prescaler
            bit [1]: 0 -> Timer en 16 bits
            bit [0]: 0 -> Modo Recarga
        */
      ORR R1, R1, R2          // Realizar OR lógico con el valor cargado
      STR R1, [R0]            // Escribir el nuevo valor de vuelta al registro


_Paginacion:
      BL _paginacion

_habilitar_INT:
      CPSIE I // hablitacion de INT en bit del registro CPSR.I 


#ifdef HABILITAR_PRUEBAS
.global _Pruebas
_Pruebas:
    BL _Pruebas_de_excepciones
#endif


_core_suspendido:
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


// Seccion de Stack
.section .stack_undefined_instruction, "ax"@nobits //para que no se genere en binario
pila_undefined_instruction: 
      .space 4096             // Pila de 4KB
fin_pila_undefined_instruction:

.section .stack_svc, "ax"@nobits //para que no se genere en binario
pila_svc: 
      .space 4096             // Pila de 4KB
fin_pila_svc: