/**
* Archivo: paginacion.s
* Función: Crea e inicializa las tablas de paginación
* Autor: Gabriel Crisafio
**/

    .global _paginacion

    .extern _STACK_INIT

    .extern _tabla_nivel_1
    .extern _exception_page_init
    .extern _timer0_page_init
    .extern _gic_page_init
    .extern _memory_page_init
    .extern _dinamic_pages_init
    @ Direcciones físicas
    .extern _ADDR_TIMER_O
    .extern _ADDR_GIC_C
    .extern _ADDR_GIC_D
    .extern _ISR_TABLE_START    
    .extern _PUBLIC_RAM_INIT
    .extern _PUBLIC_STACK_INIT
    .extern _PUBLIC_PAGES_INIT
    .extern _PUBLIC_USR_MEM_INIT

    .extern _long_tables

    .section .text_pagination

_paginacion:
@ Borro (pongo en 0) todo el espacio de memoria en donde se colocan las tablas 
@ de paginación
    ldr r1, =_tabla_nivel_1
    ldr r2, =_long_tables
    mov r0, #0
_borrado:
    strb r0, [r1], #1
    subs r2, #1
    bne _borrado
/**
* Creo e inicializo las tablas de paginación
**/
// Tabla de primer nivel
Paginacion_ISR_Table:
    @ Primer entrada: Excepción (0x00000000)
    LDR R0, =0x00000000
    LDR R6, =0x00000000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    LDR R4, =L2_first_page  @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

Paginacion_Timer:
    LDR R0, =0x10011000
    LDR R6, =0x10011000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion


Paginacion_GIC_CPU_Interface:
    LDR R0, =0x1E000000
    LDR R6, =0x1E000000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

Paginacion_GIC_Distributor:
    LDR R0, =0x1E001000
    LDR R6, =0x1E001000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

Paginacion_Stack:
    LDR R0, =0x70020000
    LDR R6, =0x70020000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

    ADD R0, R0, #0x1000 @ Debemos Paginar todos los Stack: proxima pagina en 0x70021000 = 0x70020000 + 4K
    ADD R6, R6, #0x1000 @ Hacemos lo mismo con Direccion_Fisica  
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion
    @ conocemos que la suma de todos los Stack entra en 8K (2 paginas)


   @               @ Tercer entrada: USR_MEM (0x70080000)
   @ ldr r0, =_memory_page_init + 0x80*4
   @ ldr r1, =_PUBLIC_USR_MEM_INIT + 0x30 + 2 
   @ str r1, [r0, #0]

    /***************************************/ 
    /*   Paginación de las páginas         */
    /***************************************/
Paginacion_L1:
    LDR R0, =_PUBLIC_PAGES_INIT
    LDR R6, =_PUBLIC_PAGES_INIT @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

@ Pagino toda la tabla de nivel 1 en un bucle menos la primer entrada
    mov r7, r4
    MOV R2, R0, LSR #12  @ R2 = R0 >> 12 = 0x00abcd1
    AND R2, R2, #0xFF    @ b = R2 = R2 & 0xFF = 0x0000d1 <-- 2do puntero de Direccion Virtual

    mov r3, #0x1000
    mov r4, #15
    mov r5, #4                          
    ldr r6, =_PUBLIC_PAGES_INIT
    mov r10, r6         @ Para mantener la iteracion y tener la direccion de la entrada
@ pagino las diferentes entradas de la tabla de nivel 1 para la paginacion dinamica
_table_level_1:
    add r2, r2, #0x01   @ 0x51, 0x52, ... 0x5E, 0x5F
    mul r8, r2, r5      @ Multiplico por 4 cada valor de la suma anterior en cada iteración
    add r9, r7, r8      @ _memory_page_init + (0x51, 0x52, ... 0x5E, 0x5F)
    add r10, r10, r3    @ 0x70051000, 0x70052000, ... 0x7003E000, 0x7003F000
    orr r10, r10, #0x32 @ _PUBLIC_PAGES_INIT + 0x32
    mov r0, r9
    mov r1, r10
    str r1, [r0, #0]    @ Genero la entrada de la tabla nivel 1 
    sub r4, #1          @ decremento el contador del loop
    cmp r4, #0
    bne _table_level_1    

Paginacion_L2:
    LDR R0, =L2_first_page
    LDR R6, =L2_first_page @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

@                 @ entrada: Exception (0x70060000)
@    ldr r0, =_memory_page_init + 0x60*4
@    ldr r1, =_exception_page_init + 0x30 + 2     
@    str r1, [r0, #0]
@                 @ entrada: Timer (0x70061000)     
@    ldr r0, =_memory_page_init + 0x61*4
@    ldr r1, =_timer0_page_init + 0x30 + 2         
@    str r1, [r0, #0]
@                 @ entrada: GIC (0x70062000)    
@    ldr r0, =_memory_page_init + 0x62*4
@    ldr r1, =_gic_page_init + 0x30 + 2           
@    str r1, [r0, #0]
@                 @ entrada: RAM (0x70063000) 
@    ldr r0, =_memory_page_init + 0x63*4
@    ldr r1, =_memory_page_init + 0x30 + 2           
@    str r1, [r0, #0]
@                 @ entrada: Dinamic Pages (0x70064000) 
@    ldr r0, =_memory_page_init + 0x64*4
@    ldr r1, =_dinamic_pages_init + 0x30 + 2           
@    str r1, [r0, #0]
    

Paginacion_RAM:
    LDR R0, =0x70010000
    LDR R6, =0x70010000 @ Cargar la dirección de _Direccion_Fisica en R6
@Tablas_RAM:
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

    @guardar R4

@    ADD R0, R0, #0x1000 @ Debemos Paginar toda la RAM: proxima pagina en 0x70011000 = 0x70010000 + 4K, Paginamos cada 4K hasta 
@    ADD R6, R6, #0x1000 @ Hacemos lo mismo con Direccion_Fisica  
@    LDR R9, =_Fin_RAM
@    CMP R9, R0 @ Comparo R9 y R0, se activan flags en CPSR
@    BGT  @ if R9 > R0 --> Paginamos

/**
*   Configuración para el uso de la paginación (MMU)
**/
// TTRB0 debe apuntar a la tabla de directorio de páginas (Tabla 1)
    ldr r0, =_tabla_nivel_1
    mcr p15, 0, r0, c2, c0, 0
// Todos los dominios van a ser clientes (0x55555555)
    ldr r0, =0x55555555
    mcr p15, 0, r0, c3, c0, 0
// Habilito el MMU
    mrc p15, 0, r1, c1, c0, 0       @ Leo el registro de control, para poder cambiar el bit necesario.
    orr r1, r1, #0x1                @ Bit 0 es habilitación de MMU.
    mcr p15, 0, r1, c1, c0, 0       @ Escribo el registro de control 
/**
* Se termina la creación e inicialización de la paginación
**/
    BX LR      


@ R0 = Direccion Virtual
@ LDR R6, =_Direccion_Fisica ; Cargar la dirección de _Direccion_Fisica en R6
@ LDR R5, =_L1        ; Cargar la dirección de _L1 en R5
@ LDR R4, =_L2        ; Cargar direccion L2 en R4
@ BL Funcion_Paginacion
.arm
Funcion_Paginacion:
    MOV R3, R4 @ R3 = R4 para completar Tabla_Nivel_2 despues
    MOV R7, R6 @ R7 = R7 (guardo valor para restaurarlo a R6 al finalizar)
// Se separa Direccion Virtual en a b c para hacer Offset
@ R0 = 0xabcd1234, ponga en R1 = 0xabc y en R2 = d1
Separacion_Direccion_Virtual:
    MOV R1, R0, LSR #20 @ a = R1 = R0 >> 20 = 0x00000abc

    MOV R2, R0, LSR #12  @ R2 = R0 >> 12 = 0x00abcd1
    AND R2, R2, #0xFF    @ b = R2 = R2 & 0xFF = 0x0000d1

Tabla_Nivel_1:
    @ luego cargar en R5 = _L1+ (R1 * 4)
    @LDR R5, =_L1        @ Cargar la dirección de _L1 en R5
    ADD R5, R5, R1, LSL #2 @ R5 = _L1 + (a*4) <-- L1+Offset: Sumar el desplazamiento (R1 * 4) a la dirección base
    ADD R4, R4, #1      @ habilitacion de Pagina = L2+1 (bit [0])
    STR R4, [R5]

Tabla_Nivel_2:
    @ luego cargar en R6 = _Direccion_Fisica + (R2 * 4)
    ADD R3, R3, R2, LSL #2 @ R3 = L2 + (b*4)   Sumar el desplazamiento (R2 * 4) a la dirección base
    ADD R6, R6, #0x32 @ Atributos R/W
    STR R6, [R3]

    MOV R6, R7

    BX LR

Incrementar_Puntero_L2:
    LDR R10, =Size_L2
    ADD R4, R4, R10  @ Cargar direccion L2 en R4
    BX LR

    