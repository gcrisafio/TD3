.extern _paginacion_T1

.global Scheduler

.extern scheduler_tick
.extern Tarea1
.extern Tarea2
.extern Tarea3

.section .text_Scheduler,"ax"@progbits

Scheduler:

    PUSH {R0} 
    Desactivar_paginacion_1: // Kernel no requiere paginacion, se ejecuta en modo privilegiado
        MRC p15, 0, r0, c1, c0, 0    // Leer SCTLR en r0
        BIC r0, r0, #0x1             // Borrar bit 0 (M = MMU enable)
        MCR p15, 0, r0, c1, c0, 0    // Escribir SCTLR con MMU deshabilitada
        ISB                         // Instruction Synchronization Barrier
        DSB                         // Data Synchronization Barrier
    POP {R0}

Cambio_al_modo_anterior:
    // como usamos IRQ_Handler debemos retornar al modo anterior a IRQ, para que se siga llamando a irq cuando llega un evento de timer
    LDR SP,=fin_registros
    PUSH {R0 ,R1}
    MOV R1, LR
    MRS   r0, SPSR        // Copia SPSR a R0
    MSR   CPSR_cxsf, r0   // Copia R0 al CPSR (restaura estado anterior)
    MOV LR, R1
    recupero_registros:
    LDR SP,=registros
    POP {R0 ,R1}



// CAMBIO DE TAREA 2 A TAREA 1, ver T1 o T2 (cambiarlos) 

Revisar_Tick:
//tener un sp de referencia para este punto
//ver segunda vuelta de T2
    PUSH   {r0, r1}

    LDR    r0, =scheduler_tick
    LDR    r1, [r0]

    CMP    r1, #2
    POPEQ   {r0, r1}
    BEQ    Cambio_T1_a_T2

    CMP    r1, #11
    POPHS   {r0, r1}
    BHS    reset_tick_y_T1   // Salta si r1 >= 11 (sin signo)

    CMP    r1, #3
    POPEQ   {r0, r1}
    BEQ    Cambio_T2_a_T3         

    // En este punto: R1 ∈ [3, 10]
    B      Cambio_a_T3

reset_tick_y_T1:
    LDR    r0, =scheduler_tick
    MOV    r1, #1
    STR    r1, [r0]
    B      Cambio_a_T1

Cambio_T1_a_T2:
// Puedo poner en el Bootloades el Scheduler que apunte directamente a T1, despues cae en IRQ, despues cae en Scheduler usando contextos
//    LDR R1, =T1_first_execute
//    LDR R0, [R1]
//    CMP R0, #0
//    // si T1 se ejecuta por primera vez, se debe ejecutar desde el principio
//        MOV R0, #0x1
//        STR R0, [R1] // indico flag que T1 ya se ejecutó
//        BEQ Tarea1
//    // si T1 ya se ejecutó, salto a donde estaba antes
//        B Inicializar_T1
//
//Tarea1:
//    MOV R10, #0x1
//    LDR R0, = _Reading_Area_T1_VMA
//    STR R10, [R0]
//
//BORRAR:
//    MOV R0,#0x8
//    MOV R1,#0x8
//    MOV R2,#0x8
//
//    B .  
//    MOVS PC, LR // NOTA DEBE HACERSE UN PC=LR DESPUES DE CAMBIAR TAREA EN VEZ DE HACER B TAREA


Guardar_Contexto_T1:
    _Inicializar_Stack_T1:
    LDR SP, =fin_contexto_T1      // Inicializar puntero SP de pila. 
    // Guardo Contexto = Registros
    PUSH {R0-R12}
    MRS  R0, CPSR                   @ Copia el estado del procesador (flags)
    PUSH {R0}
    PUSH {LR}

Cambio_de_arbol_de_paginacion_y_ASID_T2:
    // Paso 1: Cambiar ASID a cero
    MRC     p15, 0, R0, c13, c0, 1   // Leer ContextIDR en R0
    BIC     R0, R0, #0xFF            // Limpiar los bits [7:0] (ASID)
    MCR     p15, 0, R0, c13, c0, 1   // Escribir ContextIDR sin ASID

    // Paso 2: Ejecutar ISB (Instruction Synchronization Barrier)
    ISB                             // Asegura que el cambio de ASID se complete

    // Paso 3: Cambiar TTBR0 para que apunte a la nueva tabla de primer nivel
    //LDR R0,=_tabla_nivel_1_T1
    //MCR p15, 0, R0, c2, c0, 0     // Escribir nuevo valor en TTBR0
    //BL _paginacion_T1

    apuntar_a_nuevo_arbol_de_paginacion_T2:
    // TTRB0 debe apuntar a la tabla de directorio de páginas.
            LDR R0,=_tabla_nivel_1_T2
            MCR p15, 0, R0, c2, c0, 0

    // Todos los dominios van a ser cliente.
            LDR R0, =0x55555555
            MCR p15, 0, R0, c3, c0, 0

//Desactivar_paginacion:
//    MRC p15, 0, r0, c1, c0, 0    // Leer SCTLR en r0
//    BIC r0, r0, #0x1             // Borrar bit 0 (M = MMU enable)
//    MCR p15, 0, r0, c1, c0, 0    // Escribir SCTLR con MMU deshabilitada
//    ISB                         // Instruction Synchronization Barrier
//    DSB                         // Data Synchronization Barrier


    // Paso 4: Ejecutar ISB nuevamente
    ISB                             // Asegura que el cambio de tabla se vea reflejado

    // Paso 5: Cambiar ASID al nuevo valor
    MOV     R2, #1                   // ASID T1 = 1
    MRC     p15, 0, R0, c13, c0, 1   // Leer ContextIDR actual
    BIC     R0, R0, #0xFF            // Limpiar bits [7:0]
    ORR     R0, R0, R2               // Insertar nuevo ASID desde R2
    MCR     p15, 0, R0, c13, c0, 1   // Escribir ContextIDR con nuevo ASID


salida_condicional_a_tarea2:
    LDR    r0, =ya_entro_tarea2       // Dirección de la bandera
    LDR    r0, [r0]                   // Cargar valor actual (0 o 1)

    CMP    r0, #0
    BNE    regreso                    // Y hacer MOVS PC, LR

    // Primera vez: marcar como que ya se entró
    LDR    r0, =ya_entro_tarea2
    MOV    r1, #1
    STR    r1, [r0]                   // Guardar 1 en la bandera
                    // Habilitar MMU
                        MRC p15, 0,R12, c1, c0, 0    // Leer reg. control.
                        ORR R12, R12, #0x1            // Bit 0 es habilitación de MMU.
                        MCR p15, 0, R12, c1, c0, 0   // Escribir reg. control.

    B     Tarea2                     // Salta a tarea2

regreso:
Traer_Contexto_T2:

    traigo_fin_de_pila_SP_T2:
        LDR SP, =contexto_T2 
    
        POP {LR} // LR contiene el lugar donde estaba ejecutando la tarea
        POP {R0}
        MSR CPSR, R0
        POP {R0-R11}

                    // Habilitar MMU
                        MRC p15, 0,R12, c1, c0, 0    // Leer reg. control.
                        ORR R12, R12, #0x1            // Bit 0 es habilitación de MMU.
                        MCR p15, 0, R12, c1, c0, 0   // Escribir reg. control.
                            ISB                         // Instruction Synchronization Barrier
                            DSB                         // Data Synchronization Barrier

    MOVS   PC, LR                     // reanudo ejecucion de tarea



Cambio_a_T1:
Cambio_de_arbol_de_paginacion_y_ASID_T1:
    PUSH {R0, R1, R2}
    // Paso 1: Cambiar ASID a cero
    MRC     p15, 0, R0, c13, c0, 1   // Leer ContextIDR en R0
    BIC     R0, R0, #0xFF            // Limpiar los bits [7:0] (ASID)
    MCR     p15, 0, R0, c13, c0, 1   // Escribir ContextIDR sin ASID

    // Paso 2: Ejecutar ISB (Instruction Synchronization Barrier)
    ISB                             // Asegura que el cambio de ASID se complete

    // Paso 3: Cambiar TTBR0 para que apunte a la nueva tabla de primer nivel
    //LDR R0,=_tabla_nivel_1_T1
    //MCR p15, 0, R0, c2, c0, 0     // Escribir nuevo valor en TTBR0
    //BL _paginacion_T1

    apuntar_a_nuevo_arbol_de_paginacion_T1:
    // TTRB0 debe apuntar a la tabla de directorio de páginas.
            LDR R0,=_tabla_nivel_1_T1
            MCR p15, 0, R0, c2, c0, 0

    // Todos los dominios van a ser cliente.
            LDR R0, =0x55555555
            MCR p15, 0, R0, c3, c0, 0

    // Paso 4: Ejecutar ISB nuevamente
    ISB                             // Asegura que el cambio de tabla se vea reflejado

    // Paso 5: Cambiar ASID al nuevo valor
    MOV     R2, #1                   // ASID T1 = 1
    MRC     p15, 0, R0, c13, c0, 1   // Leer ContextIDR actual
    BIC     R0, R0, #0xFF            // Limpiar bits [7:0]
    ORR     R0, R0, R2               // Insertar nuevo ASID desde R2
    MCR     p15, 0, R0, c13, c0, 1   // Escribir ContextIDR con nuevo ASID

    POP {R0, R1, R2}

Traer_Contexto_T1:
    traigo_fin_de_pila_SP_T1:
        LDR SP, =contexto_T1 
    
        POP {LR} // LR contiene el lugar donde estaba ejecutando la tarea
        POP {R0}
        MSR CPSR, R0
        POP {R0-R11} // Tarea1 usa R0,R1,R2
            Activar_paginacion_T1:
                    // Habilitar MMU
                    Habilitar_MMU_T1:
                        MRC p15, 0,R12, c1, c0, 0    // Leer reg. control.
                        ORR R12, R12, #0x1            // Bit 0 es habilitación de MMU.
                        MCR p15, 0, R12, c1, c0, 0   // Escribir reg. control.
                            ISB                         // Instruction Synchronization Barrier
                            DSB                         // Data Synchronization Barrier
    MOVS   PC, LR                     // reanudo ejecucion de tarea


Cambio_T2_a_T3:

Guardar_Contexto_T2:
    _Inicializar_Stack_T2:
    LDR SP, =fin_contexto_T2      // Inicializar puntero SP de pila. 
    // Guardo Contexto = Registros
    PUSH {R0-R12}
    MRS  R0, CPSR                   @ Copia el estado del procesador (flags)
    PUSH {R0}
    PUSH {LR}

Cambio_de_arbol_de_paginacion_y_ASID_kernel:

    Desactivar_paginacion: // Kernel no requiere paginacion, se ejecuta en modo privilegiado
        MRC p15, 0, r0, c1, c0, 0    // Leer SCTLR en r0
        BIC r0, r0, #0x1             // Borrar bit 0 (M = MMU enable)
        MCR p15, 0, r0, c1, c0, 0    // Escribir SCTLR con MMU deshabilitada
        ISB                         // Instruction Synchronization Barrier
        DSB                         // Data Synchronization Barrier


    B Tarea3



Cambio_a_T3:
    B Tarea3

.section .bss
fin_pila_T2:
    .space 4 

.section .data
// si T1 se ejecuta por primera vez, se debe ejecutar desde el principio
T1_first_execute:
    .word 0x0000
//va a tener que estar inicializado en pila T2
//1) inicializar pilas de T1 y T2


// Seccion de Stack
.section .tarea1_stack, "ax"@nobits //para que no se genere en binario
pila_tarea1: 
      .space 4096             // Pila de 4KB
fin_pila_tarea1:


.section .bss
contexto_T1:
    .space 15*4 // cantidad de registros que tiene contexto de tarea
fin_contexto_T1:

.section .bss
contexto_T2:
    .space 15*4 // cantidad de registros que tiene contexto de tarea
fin_contexto_T2:

.section .bss
ya_entro_tarea2:
    .space 1

.section .bss
    .align 2              // Alinea a 4 bytes
registros: //espacio para guardar registros
    .space 8
fin_registros:

//en algun lado se pisa el contenido del contexto_T2



