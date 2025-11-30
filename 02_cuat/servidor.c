/**********************************************************/
/* Mini web server por Gabriel Crisafio (4/11/2025)       */
/* (Archivo comentado por Gemini)                         */
/* (Modificado para escribir "Actualizar" en el driver)   */
/**********************************************************/
#include <stdio.h>      // Para printf, perror, fopen, etc.
#include <stdlib.h>     // Para exit, atoi, malloc, free
#include <unistd.h>     // Para fork, close, getpid, read, write
#include <string.h>     // Para strcmp, strcpy, strlen, strstr
#include <sys/types.h>    // Para tipos de datos de sockets y semáforos
#include <sys/socket.h> // Para socket, bind, listen, accept
#include <netinet/in.h> // Para struct sockaddr_in, INADDR_ANY
#include <arpa/inet.h>  // Para inet_ntoa, htons, etc.
#include <errno.h>      // Para `errno`
#include <fcntl.h>      // ***NUEVO***: Para open, O_WRONLY

// --- NUEVOS HEADERS PARA IPC (SEMAFOROS) Y SEÑALES ---
#include <sys/ipc.h>    // Para ftok, semget, semop, semctl
#include <sys/sem.h>    // Para struct sembuf, semun
#include <signal.h>     // Para signal, SIGINT

#define MAX_CONN 10 //Nro maximo de conexiones en espera

// --- DEFINICIONES PARA EL MANEJO DEL ARCHIVO ---
#define HTML_FILE "datos_http.txt" // El archivo que se comparte
#define TEMP_FILE "datos_http.tmp" // Archivo temporal para modificaciones
#define DRIVER_FILE "/dev/gpio_td3" // ***NUEVO***: Definición del driver

// --- DEFINICIONES PARA EL SEMAFORO ---
// ftok genera una llave única basada en un path (existente) y un ID.
#define SEM_KEY_PATH "."  // Usar el directorio actual
#define SEM_KEY_ID 'S'  // Un ID de caracter arbitrario

// ID global del semáforo. Se usa en main() y en cleanup().
int semid;

// Unión necesaria para algunas operaciones de semctl (control del semáforo)
// Específicamente para SETVAL (inicializar el valor).
union semun {
    int val;
    struct semid_ds *buf;
    unsigned short *array;
};

// --- PROTOTIPOS DE FUNCIONES ---
void ProcesarCliente(int s_aux, struct sockaddr_in *pDireccionCliente, int puerto);
void sem_wait(int semid); // Operación P (wait/esperar/bajar)
void sem_post(int semid); // Operación V (post/signal/subir)
void cleanup(int sig);     // Manejador para Ctrl+C (SIGINT)

/**********************************************************/
/* funcion MAIN (Modificada para crear el semáforo)       */
/**********************************************************/
int main(int argc, char *argv[])
{
    int s; // Socket principal del servidor (escucha)
    struct sockaddr_in datosServidor; // Struct con info del servidor (puerto, IP)
    socklen_t longDirec; // Tamaño del struct de dirección

    // 1. Validar argumentos
    if (argc != 2)
    {
        printf("\n\nLinea de comandos: webserver Puerto\n\n");
        exit(1);
    }

    // --- 2. INICIO: CREACION DEL SEMAFORO ---
    
    // 2a. Generar una llave (key_t) única para el semáforo.
    key_t key = ftok(SEM_KEY_PATH, SEM_KEY_ID);
    if (key == -1)
    {
        perror("Error en ftok");
        exit(1);
    }

    // 2b. Crear un "set" de semáforos (en este caso, 1 semáforo)
    semid = semget(key, 1, IPC_CREAT | 0666);
    if (semid == -1)
    {
        perror("Error en semget (¿quedó un semáforo colgado de una ejecución anterior?)");
        printf("Intente limpiarlo con: ipcrm -S $(ftok %s %c)\n", SEM_KEY_PATH, SEM_KEY_ID);
        exit(1);
    }

    // 2c. Inicializar el semáforo (el semáforo '0' de nuestro 'set')
    union semun su;
    su.val = 1; // Valor de inicialización
    if (semctl(semid, 0, SETVAL, su) == -1)
    {
        perror("Error en semctl (SETVAL)");
        exit(1); // No se pudo inicializar
    }

    // 2d. Registrar el manejador 'cleanup' para la señal SIGINT (Ctrl+C).
    signal(SIGINT, cleanup);
    printf("Semáforo (id %d) creado e inicializado en 1.\n", semid);
    // --- FIN: CREACION DEL SEMAFORO ---


    // --- 3. CONFIGURACIÓN DEL SOCKET ---
    
    // 3a. Crear el socket (AF_INET = IPv4, SOCK_STREAM = TCP)
    s = socket(AF_INET, SOCK_STREAM, 0);
    if (s == -1)
    {
        printf("ERROR: El socket no se ha creado correctamente!\n");
        cleanup(0); // Limpiar el semáforo antes de salir
        exit(1);
    }
    
    // 3b. Llenar la estructura de datos del servidor
    datosServidor.sin_family = AF_INET; // IPv4
    datosServidor.sin_port = htons(atoi(argv[1])); // Puerto (convertido a network byte order)
    datosServidor.sin_addr.s_addr = htonl(INADDR_ANY); // Escuchar en todas las IPs locales

    // 3c. "Enlazar" el socket al puerto/IP
    if( bind(s, (struct sockaddr*)&datosServidor, sizeof(datosServidor)) == -1)
    {
        printf("ERROR: este proceso no puede tomar el puerto %s\n", argv[1]);
        cleanup(0); // Limpiar semáforo
        exit(1);
    }
    
    printf("\nIngrese en el navegador http://dir ip servidor:%s/\n", argv[1]);

    // 3d. Poner el socket en modo "escucha" (listen)
    if (listen(s, MAX_CONN) < 0)
    {
        perror("Error en listen");
        cleanup(0);
        close(s);
        exit(1);
    }
    
    // --- 4. BUCLE PRINCIPAL DEL SERVIDOR ---
    while (1)
    {
        int pid, s_aux; // pid para fork, s_aux para el socket del cliente
        struct sockaddr_in datosCliente; // Struct para info del cliente
        
        longDirec = sizeof(datosCliente);
        
        // 4a. Esperar una conexión (BLOQUEANTE)
        s_aux = accept(s, (struct sockaddr*) &datosCliente, &longDirec);
        if (s_aux < 0)
        {
            perror("Error en accept");
            continue; // No tirar el servidor, solo saltar esta conexión fallida
        }
        
        // 4b. Crear un proceso hijo para manejar a este cliente
        pid = fork();
        
        if (pid < 0)
        {
            perror("No se puede crear un nuevo proceso mediante fork");
            close(s_aux); // Cerrar el socket del cliente
            continue;
        }
        
        if (pid == 0)
        {   
            // --- CÓDIGO DEL PROCESO HIJO ---
            close(s); // El hijo no necesita el socket principal de escucha
            ProcesarCliente(s_aux, &datosCliente, atoi(argv[1]));
            exit(0); // El hijo termina su trabajo y sale
        }
        
        // --- CÓDIGO DEL PROCESO PADRE ---
        close(s_aux); // El padre no necesita el socket de este cliente
    }

    return 0; // Nunca se alcanza
}

// --- NUEVA: Manejador de señal para limpieza ---
void cleanup(int sig)
{
    printf("\nCerrando servidor. Eliminando semáforo (id %d)...\n", semid);
    
    // Eliminar el set de semáforos del kernel.
    if (semctl(semid, 0, IPC_RMID) == -1)
    {
        perror("Error al eliminar semáforo (semctl IPC_RMID)");
    }
    exit(0);
}

// --- NUEVA: Operación P (wait) ---
void sem_wait(int semid)
{
    struct sembuf sops;
    sops.sem_num = 0;     // Operar sobre el semáforo 0
    sops.sem_op = -1;     // Restar 1 (wait)
    sops.sem_flg = 0;     // Bloqueante
    if (semop(semid, &sops, 1) == -1)
    {
        perror("Error en sem_wait (semop P)");
    }
}

// --- NUEVA: Operación V (post) ---
void sem_post(int semid)
{
    struct sembuf sops;
    sops.sem_num = 0;     // Operar sobre el semáforo 0
    sops.sem_op = 1;      // Sumar 1 (post/signal)
    sops.sem_flg = 0;     // Bloqueante
    if (semop(semid, &sops, 1) == -1)
    {
        perror("Error en sem_post (semop V)");
    }
}


// --- FUNCION ProcesarCliente MODIFICADA PARA USAR SEMAFOROS ---
void ProcesarCliente(int s_aux, struct sockaddr_in *pDireccionCliente,
                     int puerto)
{
    char bufferComunic[4096]; // Buffer para leer la petición HTTP
    char responseBuffer[8192];  // Buffer para armar la respuesta HTTP
    char ipAddr[20];
    int Port;

    strcpy(ipAddr, inet_ntoa(pDireccionCliente->sin_addr));
    Port = ntohs(pDireccionCliente->sin_port);
    
    // 1. Leer la petición HTTP del cliente (navegador)
    if (recv(s_aux, bufferComunic, sizeof(bufferComunic), 0) == -1)
    {
        perror("Error en recv");
        exit(1); // Salir del proceso hijo
    }
    
    printf("* Recibido del navegador Web %s:%d:\n%s\n",
           ipAddr, Port, bufferComunic);
    
    // 2. Parsear la petición HTTP (de forma muy simple)
    char method[10]; // GET, POST
    char path[256];  // /, /agregar, /eliminar
    
    if (sscanf(bufferComunic, "%s %s", method, path) < 2)
    {
        printf("Peticion mal formada.\n");
        close(s_aux);
        return; // Salir del hijo
    }

    // --- RUTA 1: GET / (Servir la página) ---
    if (strcmp(method, "GET") == 0 && strcmp(path, "/") == 0)
    {
        FILE *fp;
        long file_size;
        char *html_content = NULL;

        // --- INICIO SECCIÓN CRÍTICA (Lectura) ---
        printf("PID %d: Esperando semáforo para LEER...\n", getpid());
        sem_wait(semid); // --- TOMAR SEMAFORO ---
        printf("PID %d: Semáforo tomado (Leyendo %s)\n", getpid(), HTML_FILE);

        fp = fopen(HTML_FILE, "rb"); 
        if (fp == NULL)
        {
            printf("ERROR: No se pudo abrir '%s'\n", HTML_FILE);
            sprintf(responseBuffer, "HTTP/1.1 500 Internal Server Error\n\nArchivo no encontrado.");
        }
        else
        {
            fseek(fp, 0, SEEK_END);
            file_size = ftell(fp);
            fseek(fp, 0, SEEK_SET);

            html_content = malloc(file_size + 1);
            if (html_content == NULL)
            {
                sprintf(responseBuffer, "HTTP/1.1 500 Internal Server Error\n\nError de memoria.");
                fclose(fp);
            }
            else
            {
                fread(html_content, 1, file_size, fp);
                html_content[file_size] = '\0';
                fclose(fp);

                printf("Accion: Sirviendo '%s' (GET /)\n", HTML_FILE);
                
                sprintf(responseBuffer,
                        "HTTP/1.1 200 OK\n"
                        "Content-Length: %ld\n"
                        "Content-Type: text/html; charset=utf-8\n"
                        "Connection: Closed\n"
                        "Refresh: 10\n\n" // Refresca el navegador cada 10 seg
                        "%s", 
                        file_size, html_content);
                
                free(html_content);
            }
        }
        
        printf("PID %d: Liberando semáforo (Lectura completa)\n", getpid());
        sem_post(semid); // --- LIBERAR SEMAFORO ---
        // --- FIN SECCIÓN CRÍTICA ---
    }
    
    // --- RUTA 2: POST /agregar o /eliminar (Modificar el archivo) ---
    else if (strcmp(method, "POST") == 0 && (strcmp(path, "/agregar") == 0 || strcmp(path, "/eliminar") == 0))
    {
        char *body = strstr(bufferComunic, "\r\n\r\n");
        char codigoStr[10];
        int codigo = -1; // Usar -1 como inválido

        if (body != NULL)
        {
            body += 4; // Saltar el doble CRLF
            if (sscanf(body, "fname=%s", codigoStr) == 1)
            {
                codigo = atoi(codigoStr); // Convertir a entero
            }
        }

        if (codigo >= 0 && codigo <= 9999) 
        {
            // --- INICIO SECCIÓN CRÍTICA (Escritura) ---
            printf("PID %d: Esperando semáforo para ESCRIBIR...\n", getpid());
            sem_wait(semid); // --- TOMAR SEMAFORO ---
            printf("PID %d: Semáforo tomado (Modificando %s)\n", getpid(), HTML_FILE);
            
            FILE *fp_orig, *fp_temp;
            char lineBuffer[2048];
            int foundMarker = 0; 

            fp_orig = fopen(HTML_FILE, "r");
            fp_temp = fopen(TEMP_FILE, "w");

            if (fp_orig == NULL || fp_temp == NULL)
            {
                perror("Error al abrir archivos (orig/temp)");
            }
            else
            {
                if (strcmp(path, "/agregar") == 0)
                {
                    // --- LÓGICA DE AGREGAR ---
                    printf("Accion: AGREGAR codigo %04d\n", codigo);
                    char newLine[100];
                    // Formatear la nueva fila (con 4 dígitos, ej: 0042)
                    sprintf(newLine, "<tr><td>%04d</td></tr>\n", codigo); 

                    while (fgets(lineBuffer, sizeof(lineBuffer), fp_orig) != NULL) 
                    {
                        if (!foundMarker && strstr(lineBuffer, "</table>") != NULL) 
                        {
                            fputs(newLine, fp_temp);
                            foundMarker = 1;
                        }
                        fputs(lineBuffer, fp_temp);
                    }
                }
                else // path == "/eliminar"
                {
                    // --- LÓGICA DE ELIMINAR ---
                    printf("Accion: ELIMINAR codigo %04d\n", codigo);
                    char lineToRemove[100];
                    sprintf(lineToRemove, "<tr><td>%04d</td></tr>", codigo);
                    
                    while (fgets(lineBuffer, sizeof(lineBuffer), fp_orig) != NULL) 
                    {
                        if (strstr(lineBuffer, lineToRemove) != NULL) 
                        {
                            continue; // Omitir esta línea
                        }
                        fputs(lineBuffer, fp_temp);
                    }
                }
                fclose(fp_orig);
                fclose(fp_temp);

                // Reemplazar el archivo
                remove(HTML_FILE);
                rename(TEMP_FILE, HTML_FILE);
                printf("PID %d: Archivo modificado.\n", getpid());

                // --- INICIO DE LA MODIFICACIÓN ---
                // Notificar al driver que se actualizó un código
                if (strcmp(path, "/agregar") == 0) 
                {
                    int fd_write;
                    printf("PID %d: Escribiendo 'Actualizar' en el driver.\n", getpid());
                    
                    // Abrir el driver
                    fd_write = open(DRIVER_FILE, O_WRONLY);
                    if (fd_write < 0) {
                        // No es un error fatal para el servidor, solo loguear
                        perror("Error al abrir driver para 'Actualizar'");
                    } else {
                        // Escribir "Actualizar\n" (11 bytes)
                        // El driver .write lo limpiará y comparará "Actualizar"
                        write(fd_write, "Actualizar\n", 11);
                        close(fd_write); // Cerrar el driver
                    }
                }
                // --- FIN DE LA MODIFICACIÓN ---
            }
            
            printf("PID %d: Liberando semáforo (Escritura completa)\n", getpid());
            sem_post(semid); // --- LIBERAR SEMAFORO ---
            // --- FIN SECCIÓN CRÍTICA ---
        }
        else
        {
            printf("Accion: POST recibido sin codigo valido.\n");
        }

        // Redireccionar al cliente (siempre se hace)
        sprintf(responseBuffer,
                "HTTP/1.1 303 See Other\n"
                "Location: /\n" // Redirigir a la página principal
                "Connection: Closed\n\n");
    }
    // --- RUTA 3: Cualquier otra cosa (404) ---
    else
    {
        printf("Accion: Ruta desconocida %s %s. Sirviendo 404.\n", method, path);
        sprintf(responseBuffer, 
                "HTTP/1.1 404 Not Found\n"
                "Content-Type: text/html\n"
                "Connection: Closed\n\n"
                "<html><body><h1>404 Not Found</h1><p>Ruta: %s</p></body></html>",
                path);
    }

    // --- 4. Enviar respuesta ---
    printf("* Enviado al navegador Web %s:%d:\n%s\n",
           ipAddr, Port, responseBuffer);
    
    if (send(s_aux, responseBuffer, strlen(responseBuffer), 0) == -1)
    {
        perror("Error en send");
    }
    
    // 5. Cerrar el socket del cliente y terminar el hijo
    close(s_aux);
}
