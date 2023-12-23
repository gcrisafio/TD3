#include <stddef.h>
#include <stdint.h>
#include "../inc/gic.h"
#include "../inc/timer.h"

// Estructura: los registros banqueados en IRQ_Handler son recibidos por la estructura ctx_t
// contenido:
// SPSR --> cpsr
// LR (contiene PC anterior a excepcion) --> pc
// R0-R12 --> gpr[13] 
// SP --> sp
// LR --> lr
typedef struct ctx_t
{
    uint32_t cpsr, pc, gpr[ 13 ], sp, lr;   //struct con registros que pasaron por IRQ_HANDLER, gpr: registros de proposito genral
} ctx_t; 

/*
    Tambien se puede escribir como
    typedef struct ctx_t
{
    uint32_t  cpsr;
    uint32_t  pc;
    uint32_t  gpr[13];
    uint32_t  sp;
    uint32_t  lr;
}ctx_t;

*/
//Variable global
void kernel_handler_irq( ctx_t* ctx);

//con __attribute__ indica que hay seccion de entrada en C al Linker Script
//step 1: IRQ_Handler BL to "kernel_handler_irq" function
__attribute__((section(".text"))) void kernel_handler_irq( ctx_t* ctx)
{
    //step 2: read the interrupt identifier so we know the source
    _gicc_t* const GICC0 = (_gicc_t*)GICC0_ADDR;
    //_timer_t* const TIMER0 = ( _timer_t*)TIMER0_ADDR;
    uint32_t id = GICC0->IAR;   //con este id conocemos quien interrumpio

    //step 4: handle the interrupt, then clear (or reset) the source
    switch (id)
    {
        case GIC_SOURCE_TIMER0 : {  
                //id timer (manual del gic)
                // TIMER0->INTCRL = 0x01;
                break;
            }
    
        default: 
            break;
    }

    //step 5: write the interrupt identifier to signal we're done
    GICC0->EOIR = id;   //se indica a GIC que termino INT para volver a atender INT con id
}
