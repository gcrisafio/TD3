//#include "td3.h"

extern char mensaje[]; // extern para avisar que es de otro archivo

void td3_memcopy(void *destino, const void *origen, unsigned int num_bytes);

/* La seccion .inicio se ejecuta en ROM, se aclara para tener LMA=VMA (lugar de ejecucicion = ROM)*/
__attribute__((section(".inicio"))) void td3_memcopy(void *destino, const void *origen, unsigned int num_bytes)
{

    char *pszDest = (char *)destino;
    const char *pszSource =( const char*)origen;

    while(num_bytes) //till cnt
    {
        //Copy byte by byte
        *(pszDest++) = *(pszSource++); // poner char* para que que en .s se genere LDRB 
        --num_bytes;
    }
    //printf("%s", mensaje);
}

// global = heap
// todo se guarda en la pila


