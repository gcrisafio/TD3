/**
 * Archivo: startup.S
 * Función: Realiza la inicialización básica del uP
 * Autor: Gabriel Crisafio
 **/

/* Referencias a funciones externas */

.extern UND_Handler
.extern SVC_Handler
.extern PREF_Handler
.extern ABT_Handler
.extern IRQ_Handler
.extern FIQ_Handler

.global _start
.global Gic_init

.extern _paginacion
.extern __gic_init

/* Referencia a variables o simbolos externos */
.extern _ISR_VECTORS_BASE
.extern __isr_table_start__

.extern _reset_vector
.extern __bss_start
.extern __bss_end


.extern __irq_stack_top__
.extern __fiq_stack_top__ 
.extern __svc_stack_top__
.extern __abt_stack_top__
.extern __und_stack_top__    
.extern __sys_stack_top__ 


/* Tamaños en Public RAM */
.equ _PUB_RAM_SYS_STACK_SIZE, 256
.equ _PUB_RAM_IRQ_STACK_SIZE, 256
.equ _PUB_RAM_FIQ_STACK_SIZE, 8
.equ _PUB_RAM_SVC_STACK_SIZE, 8
.equ _PUB_RAM_ABT_STACK_SIZE, 8
.equ _PUB_RAM_UND_STACK_SIZE, 8

/* 
 Definimos bits del CPSR para los diferentes modos
   
 CPSR: Current Program Status Register - Ver ARM B1
 El SPSR posee la misma estructura que el CPSR, solo que se refiere al
 "Saved Program Status Register".
 */

.equ USR_MODE, 0x10    /* USER       - Encoding segun ARM B1.3.1 (pag. B1-1139): 10000 - Bits 4:0 del CPSR */
.equ FIQ_MODE, 0x11    /* FIQ        - Encoding segun ARM B1.3.1 (pag. B1-1139): 10001 - Bits 4:0 del CPSR */
.equ IRQ_MODE, 0x12    /* IRQ        - Encoding segun ARM B1.3.1 (pag. B1-1139): 10010 - Bits 4:0 del CPSR */
.equ SVC_MODE, 0x13    /* Supervisor - Encoding segun ARM B1.3.1 (pag. B1-1139): 10011 - Bits 4:0 del CPSR */
.equ ABT_MODE, 0x17    /* Abort      - Encoding segun ARM B1.3.1 (pag. B1-1139): 10111 - Bits 4:0 del CPSR */
.equ UND_MODE, 0x1B    /* Undefined  - Encoding segun ARM B1.3.1 (pag. B1-1139): 11011 - Bits 4:0 del CPSR */
.equ SYS_MODE, 0x1F    /* System     - Encoding segun ARM B1.3.1 (pag. B1-1139): 11111 - Bits 4:0 del CPSR */
.equ I_BIT,    0x80    /* Mask bit I - Encoding segun ARM B1.3.3 (pag. B1-1149) - Bit 7 del CPSR */
.equ F_BIT,    0x40    /* Mask bit F - Encoding segun ARM B1.3.3 (pag. B1-1149) - Bit 6 del CPSR */

/* Modo de funcionamiento: arm */
.code 32

_start:

/* Limpiamos la sección BSS - Sugerido por Starterware */
_clear_BSS:
    LDR R0, =__bss_start__      /* Dirección de inicio de la sección BSS (pública) */
    LDR R1, =__bss_end__        /* Dirección final de la sección BSS (pública) */
    MOV R2, #0                  /* Copiamos el valor "0" en R2 */
    CMP R0,R1
    BEQ _STACK_INIT             /* Para el caso particular en el que bss está vacía (__bss_start__ == __bss_end__) no hay nada que inicializar, asi que me salteo el loop */
_LOOP:
    STR R2, [R0], #4            /* El contenido de R2 es cargado en "lo apuntado" por R0, luego incrementa la dirección de R0 */
    CMP R0, R1                  /* Comparamos R0 y R1, que poseen las direcciones de interés */
    BLE _LOOP                   /* Mientras la comparación anterior sea falsa, se vuelve a _LOOP */

_STACK_INIT:
    /* Inicializamos los stack pointers para los diferentes modos de funcionamiento */
    MSR cpsr_c,#(IRQ_MODE | I_BIT |F_BIT)
    LDR SP,=__irq_stack_top__     /* IRQ stack pointer */

    MSR cpsr_c,#(FIQ_MODE | I_BIT |F_BIT)
    LDR SP,=__fiq_stack_top__     /* FIQ stack pointer */

    MSR cpsr_c,#(SVC_MODE | I_BIT |F_BIT)
    LDR SP,=__svc_stack_top__     /* SVC stack pointer */

    MSR cpsr_c,#(ABT_MODE | I_BIT |F_BIT)
    LDR SP,=__abt_stack_top__     /* ABT stack pointer */

    MSR cpsr_c,#(UND_MODE | I_BIT |F_BIT)
    LDR SP,=__und_stack_top__     /* UND stack pointer */

    MSR cpsr_c,#(SYS_MODE | I_BIT |F_BIT)
    LDR SP,=__sys_stack_top__     /* SYS stack pointer */

Retorno:
    MOV PC, LR

//Paginacion:
//    BL _paginacion


    /* Habilitacion de IRQ en registro CPSR */
Habilitar_IRQ:
    MRS R0, cpsr
    BIC R0, R0, #0x80 
    MSR cpsr_c, R0 // Habilita IRQ

    /* Activar modo System */

prueba_SVC_Handler: //NOTA cuando el procesador entra a un Handler de Excepcion se guarda CPSR --> SPSR automaticamente
    SWI 95
    
idle:
    WFI

.end

/* Funciones para probar Excepctions Handlers */
prueba_UND_Handler:
    udf #0

prueba_ABT_Handler:
    /* Para probar ABT_Handler debe configurarse MMU */

prueba_SVC_Handler:
    SWI 95

lectura_Timer:
    LDR R0, =0x10011004
    LDR R1, [R0]