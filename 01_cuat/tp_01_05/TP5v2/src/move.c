void move(unsigned int *origen, unsigned int *destino,  unsigned int count);

/* La seccion .inicio se ejecuta en ROM, se aclara para tener LMA=VMA (lugar de ejecucicion = ROM)*/
// R0 = unsigned int *origen (direccion)
// R1 = unsigned int *destino (direccion)
// R2 = unsigned int count (Dato)
// cada uno tiene una direccion/dato de maximo 4B (tamaño de Registro)
__attribute__((section(".inicializacion"))) void move(unsigned int *origen, unsigned int *destino,  unsigned int count)
{   
    char * porigen = (char*) origen;
    char * pdestino = (char*) destino;

    while(count) 
    {
        //Copy byte by byte
        *(pdestino++) =*(porigen++); // poner char* para que que en .s se genere LDRB 
        --count;
    }
}