
#include "../inc/gic.h"

__attribute__((section(".inicializacion"))) void __gic_init()
    {
        _gicc_t* const GICC0 = (_gicc_t*)GICC0_ADDR;
        _gicd_t* const GICD0 = (_gicd_t*)GICD0_ADDR;


        GICC0->PMR  = 0x000000F0;
        GICD0->ISENABLER[1] |= 0x00000010;
        //GICD0->ISENABLER[1] |= 0x00001000; No habilito Puerto Serie
        GICC0->CTLR         = 0x00000001;
        GICD0->CTLR         = 0x00000001;


    }