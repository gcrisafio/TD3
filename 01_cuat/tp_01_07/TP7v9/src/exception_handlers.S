/**
 * Archivo: exception_handlers.s
 * Función: manejadores de las excepciones
 * Autor: Gabriel Crisafio
 **/


.global UND_Handler
.global SVC_Handler
.global PREF_Handler
.global ABT_Handler
.global IRQ_Handler
.global FIQ_Handler

.global scheduler_tick

.extern kernel_handler_irq
.extern Scheduler

.section .data
.global aux @ cada Tarea lee esta variable para ceder el mando
aux: .word 0 @ Contador de ticks (asociado con IRQ_Handler), cont = 0 y cont+=1 por cada tick de IRQ

.section .section_exception_handlers,"ax"@progbits
//NOTA cuando el procesador entra a un Handler de Excepcion se guarda CPSR --> SPSR automaticamente

UND_Handler:  
    SUB LR, LR, #4 // LR = LR - 4
    /* Guardar R10 */
    PUSH { R10 } // dentro del Handler voy a utilizar R10 pusheo a la pila para guardar contenido anterior y no cortar secuencia

    LDR R11, =_UND_string
    LDR R10, [R11]
 
    MOV R10, #0
    STR R10, [LR] // [Instruccion No Definida] = 0x0000 0000 = andeq r0, r0, r0

    POP { R10 } // restauro valores

    MOVS PC, LR // MOV PC, LR y MOV CPSR, SPSR

SVC_Handler: // Parametros R0-R1-R2-R3
    LDR R4,[LR,#-4] // veo instruccion que genero SVC para obtener el parametro
    AND R4,#0x1 // me quedo con bit 0
    CMP R4,#0x1
    BEQ suma_svc
    BNE resta_svc

suma_svc:
    // R1:R0 + R3:R2
    ADDS R0, R0, R2 // Sumar las partes bajas (R0+R2) y ajusar el flag Carry
    ADC R1, R1, R3 // Sumar las partes altas (R1+R3) incluyendo el acarreo

    MOVS PC, LR

resta_svc:
    // R1:R0 - R3:R2
    SUBS R0, R0, R2 // Resta las partes bajas (R0-R2) y ajustar el flag de acarreo
    SBC R1, R1, R3 // Restar las partes altas (R1-R3) incluyendo el acarreo

    MOVS PC, LR

PREF_Handler:
    SUB LR, LR, #4 // LR = LR - 4

    MOVS PC, LR


ABT_Handler:
    SUB LR, LR, #8 // LR = LR - 8

    /* Guardar R10 = "MEM" */
    //PUSH { R0, R10, R12 } // dentro del Handler voy a utilizar R10 y R12, pusheo a la pila para guardar contenido anterior y no cortar secuencia
    
    //LDR R12, =_ABT_string
    //LDR R10, [R12]
    //podriamos ver aca si SPSR anterior es de IRQ, si es asi desactivar paginacion

    Chequear_Y_Deshabilitar_MMU_Si_IRQ:
        // uso R12 porque ese registro no se usa en las tareas
        MRS     r12, SPSR           // Leer SPSR
        AND     r12, r12, #0x1F     // Extraer modo (bits M[4:0])
        CMP     r12, #0x12          // Comparar con modo IRQ (0x12)
        BNE     fin_chequeo         // Si no es IRQ, salir

        // Deshabilitar MMU (si estamos viniendo de IRQ)
        MRC     p15, 0, r12, c1, c0, 0   // Leer control register
        BIC     r12, r12, #0x1           // Limpiar bit 0 (MMU enable)
        MCR     p15, 0, r12, c1, c0, 0   // Escribir control register
        ISB                         // Instruction Synchronization Barrier
        DSB                         // Data Synchronization Barrier
        B retorno

    fin_chequeo:

    retorno:
    //POP { R0, R10, R12 } // restauro valores
    MOVS PC, LR


IRQ_Handler:
    SUB LR, LR, #4 // LR = LR - 4 @retornar a la instruccion en ejecucion al momento de la interrupcion
    //inicializar SP_IRQ
    LDR SP, =__irq_stack_top__
    stmfd sp!, {r0-r12, lr}             @resguarda contexto en pila de IRQ

    mrs r11, spsr                       @reguarda Saved Processor Status Register
    push {r11}

    PUSH {R0} 
    Desactivar_paginacion_1: // Kernel no requiere paginacion, se ejecuta en modo privilegiado
        MRC p15, 0, r0, c1, c0, 0    // Leer SCTLR en r0
        BIC r0, r0, #0x1             // Borrar bit 0 (M = MMU enable)
        MCR p15, 0, r0, c1, c0, 0    // Escribir SCTLR con MMU deshabilitada
        ISB                         // Instruction Synchronization Barrier
        DSB                         // Data Synchronization Barrier
    POP {R0}

_Contador_IRQ:
    LDR R10, =contador_IRQ
    LDR R8, [R10]
    ADD R8, R8, #1
    STR R8, [R10]

    /* Handler Code */
    BL kernel_handler_irq

    incrementar_contador_Scheduler:
    LDR  r0, =scheduler_tick   // Cargar dirección del contador
    LDR  r1, [r0]              // Leer valor actual
    ADD  r1, r1, #1            // Incrementar
    STR  r1, [r0]              // Guardar nuevo valor


    pop {r11}
    msr spsr, r11                       @reguarda Saved Processor Status Register    

    ldmfd sp!, {r0-r12, lr}            @restaura contexto y retorna
    B Scheduler


FIQ_Handler:
    SUB LR, LR, #4 // LR = LR - 4

    MOVS PC, LR


/* Seccion de datos inicializados */ 
.section .data
_IRQ_string:
    .asciz "IRQ"

.section .data
_UND_string:
    .asciz "INV"

.section .data
_ABT_string:
    .asciz "MEM"

.section .data
_SVC_string:
    .asciz "SVC"

.section .data 
contador_IRQ: .word 0

.section .data
scheduler_tick:
    .word 1         // Variable de 32 bits (contador)