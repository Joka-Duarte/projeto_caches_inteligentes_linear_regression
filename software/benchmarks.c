#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// --- CONFIGURAÇÕES DE TAMANHO ---
#define L2_SIZE_BYTES (128 * 1024) 
#define ARRAY_SIZE    (L2_SIZE_BYTES * 2 / sizeof(int)) // 65536 inteiros = 256 KB

// --- MACROS PARA MÉTRICAS ---
#define START_PERF() 
#define END_PERF()   

// Macros injetadas para avisar o Python dos acessos
#define TRACE_D(addr) printf("D 0x%lx\n", (unsigned long)(addr))
#define TRACE_I(addr) printf("I 0x%lx\n", (unsigned long)(addr))

typedef struct Node {
    int data;
    struct Node *next;
} Node;

// --- DEFINIÇÃO DOS BENCHMARKS ---

void run_streaming(int *array, volatile int *hot_data) {
    for (int it = 0; it < 10; it++) {
        for (int i = 0; i < ARRAY_SIZE; i++) {
            TRACE_I(0x400000); 
            
            TRACE_D(&array[i]); 
            array[i] += i;
            TRACE_D(&array[i]); 
            
            if (i % 64 == 0) {
                TRACE_I(0x400008); 
                TRACE_D(hot_data);
                *hot_data += array[i]; 
                TRACE_D(hot_data);
            }
        }
    }
}

void run_matrix_conv(int *img, int *out) {
    int width = 128;
    int height = ARRAY_SIZE / width;
    
    for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
            TRACE_I(0x401000); 
            
            TRACE_D(&img[(y-1)*width+x]);
            TRACE_D(&img[y*width+x]);
            TRACE_D(&img[(y+1)*width+x]);
            
            TRACE_D(&out[y*width+x]); 
            out[y*width+x] = img[(y-1)*width+x] + img[y*width+x] + img[(y+1)*width+x];
        }
    }
}

void run_linked_list(Node *nodes, int count) {
    Node *curr = nodes;
    for (int i = 0; i < count * 50; i++) {
        TRACE_I(0x402000); 
        
        TRACE_D(&curr->data); 
        curr->data += i;
        TRACE_D(&curr->data); 
        
        TRACE_D(&curr->next); 
        curr = curr->next;
    }
}

void run_pattern_search(uint8_t *blob, int size) {
    for (int i = 1024; i < size; i++) {
        for (int j = 1; j < 64; j++) {
            TRACE_I(0x403000); 
            
            TRACE_D(&blob[i]);
            TRACE_D(&blob[i-j]);
            
            if (blob[i] == blob[i-j]) { 
                TRACE_I(0x403008); 
                TRACE_D(&blob[i]); 
                blob[i]++; 
                TRACE_D(&blob[i]); 
                break; 
            }
        }
    }
}

// ====================================================================
// NOVO: BENCHMARK x1
// ====================================================================
void run_aira_killer(int *junk_array, int *vip_array) {
    int tam_junk = ARRAY_SIZE; // 256 KB de lixo (Maior que a L2 de 128KB)
    int tam_vip = 2048;        // 8 KB de dados cruciais (Cabe folgado na L2)

    // FASE 1: Aquecimento do VIP (Treinando a AIRA para subir a Frequência)
    for (int iter = 0; iter < 10; iter++) {
        for (int i = 0; i < tam_vip; i += 16) { 
            TRACE_I(0x404000); // Instrução do loop
            TRACE_D(&vip_array[i]); // Leitura do dado VIP
        }
    }

    // FASE 2: A Armadilha (Scan Resistance Test)
    for (int round = 0; round < 5; round++) {
        
        // 2A. A Inundação: Lemos os 256KB de lixo. 
        // O LRU limpa a L2 inteira. O AIRA protege o VIP.
        for (int j = 0; j < tam_junk; j += 16) {
            TRACE_I(0x404004); 
            TRACE_D(&junk_array[j]);
        }

        // 2B. A Consequência: Retornamos ao VIP.
        // O LRU sofrerá 100% de Miss aqui. O AIRA dará Hit.
        for (int i = 0; i < tam_vip; i += 16) {
            TRACE_I(0x404008); 
            TRACE_D(&vip_array[i]);
        }
    }
}

// --- MENU PRINCIPAL ---

void print_menu() {
    fprintf(stderr, "========================================\n");
    fprintf(stderr, "   SELETOR DE BENCHMARKS - CACHE IA     \n");
    fprintf(stderr, "========================================\n");
    fprintf(stderr, "1. Streaming + HotSet (L1/L2 Data)\n");
    fprintf(stderr, "2. Matrix Convolution (Temporal Reuse)\n");
    fprintf(stderr, "3. Linked List Traversal (Pointer Chasing)\n");
    fprintf(stderr, "4. Pattern Search (L2 Unified Stress)\n");
    fprintf(stderr, "5. Executar Todos em Sequência (1 a 4)\n");
    fprintf(stderr, "6. Carga Adversarial (AIRA vs LRU)\n");
    fprintf(stderr, "0. Sair\n");
    fprintf(stderr, "Escolha uma opção: ");
}

int main() {
    int choice = -1;
    volatile int hot_val = 0;

    int *big_array = (int *)calloc(ARRAY_SIZE, sizeof(int));
    int *out_array = (int *)calloc(ARRAY_SIZE, sizeof(int));
    uint8_t *blob   = (uint8_t *)malloc(L2_SIZE_BYTES);
    
    // Array VIP de 8KB para o teste do AIRA
    int *vip_array = (int *)calloc(2048, sizeof(int)); 
    
    Node *nodes = (Node *)malloc(2000 * sizeof(Node));
    for(int i=0; i<1999; i++) nodes[i].next = &nodes[i+1];
    nodes[1999].next = &nodes[0];

    while (choice != 0) {
        print_menu();
        if (scanf("%d", &choice) != 1) break;

        switch (choice) {
            case 1: run_streaming(big_array, &hot_val); break;
            case 2: run_matrix_conv(big_array, out_array); break;
            case 3: run_linked_list(nodes, 2000); break;
            case 4: run_pattern_search(blob, L2_SIZE_BYTES); break;
            case 5:
                run_streaming(big_array, &hot_val);
                run_matrix_conv(big_array, out_array);
                run_linked_list(nodes, 2000);
                run_pattern_search(blob, L2_SIZE_BYTES);
                break;
            case 6: run_aira_killer(big_array, vip_array); break;
            case 0: fprintf(stderr, "Encerrando...\n"); break;
            default: fprintf(stderr, "Opção inválida!\n");
        }
    }

    free(big_array); free(out_array); free(nodes); free(blob); free(vip_array);
    return 0;
}