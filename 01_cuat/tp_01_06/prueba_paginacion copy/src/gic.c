
#include "../inc/gic.h"

// NOTA funciones en C por defecto estan en seccion .text
void gic_init()
    {
        // GIC0 generates Cortex-A8 nIRQ
        _gicc_t* const CPU_INTERFACE = (_gicc_t*)GICC0_ADDR;
        _gicd_t* const DISTRIBUTOR = (_gicd_t*)GICD0_ADDR;

        CPU_INTERFACE->PMR  = 0x000000F0; // with priority 0xF are masked but interrupts with higher priority values 0x0
        DISTRIBUTOR->ISENABLER[1] |= (1 << (GIC_SOURCE_TIMER0 - 32));
        CPU_INTERFACE-> CTLR = 1; // Enable the CPU interface for this GIC
        DISTRIBUTOR-> CTLR   = 1; // Enable GIC Distributor


    }