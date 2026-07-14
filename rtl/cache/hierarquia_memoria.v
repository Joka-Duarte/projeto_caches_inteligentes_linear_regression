`timescale 1ns/1ps
// O integrador central. Faz o roteamento entre a CPU, as duas caches L1, a L2 e a RAM.
// Lida com conflitos de requisição e compatibiliza os tamanhos de blocos diferentes.

module hierarquia_memoria (
    input  wire        clk,
    input  wire        rst,

    // Barramento de leitura de código da CPU (L1 de Instruções)
    input  wire        req_instrucao,
    input  wire [31:0] addr_instrucao,
    output wire [31:0] dado_instrucao,
    output wire        hit_instrucao,

    // Barramento de leitura de variáveis da CPU (L1 de Dados)
    input  wire        req_dado,
    input  wire [31:0] addr_dado,
    output wire [31:0] dado_leitura,
    output wire        hit_dado,

    // Sinais da CPU prevendo qual será o próximo endereço a ser lido (Look-ahead)
    input  wire        la_valid,
    input  wire [31:0] la_addr,

    // Barramento expresso para escritas (Store Write-through). 
    // Vai direto para a RAM sem alocar nas caches.
    input  wire        req_escrita,
    input  wire [31:0] addr_escrita,
    input  wire [3:0]  wstrb,
    input  wire [31:0] wdata,

    // Sinais de monitoramento para o nível superior
    output wire        miss_l2,
    output wire        ram_ready_out
);

    wire        miss_l1i, miss_l1d;
    wire [31:0] addr_miss_l1i, addr_miss_l1d;

    // Árbitro de Hardware: Define quem vai pedir dados para a L2.
    // Se as duas L1 errarem ao mesmo tempo, a L1 de Instruções tem prioridade.
    wire        req_l2  = miss_l1i | miss_l1d;
    wire [31:0] addr_l2 = miss_l1i ? addr_miss_l1i : addr_miss_l1d;

    wire [511:0] l2_data_out;
    wire         hit_l2;
    wire         l2_data_ready;

    wire [511:0] ram_data_out;
    wire         ram_ready;
    wire         ram_data_ready_pulse;
    wire [31:0]  addr_ram;

    assign ram_ready_out = ram_ready;

    // Instanciação da simulação de Memória RAM Externa
    ram_principal RAM (
        .clk           (clk),
        .rst           (rst),
        .req           (miss_l2),
        .addr          (addr_l2),
        .data_out      (ram_data_out),
        .ready         (ram_ready),
        .ram_data_ready(ram_data_ready_pulse),
        .we            (req_escrita),
        .wstrb         (wstrb),
        .wdata         (wdata),
        .waddr         (addr_escrita)
    );

    // Instanciação da Cache L2 equipada com Inteligência AIRA
    cache_l2_aira L2_Unificada (
        .clk           (clk),
        .rst           (rst),
        .req           (req_l2),
        .addr          (addr_l2),
        .ram_data_in   (ram_data_out),
        .ram_data_ready(ram_data_ready_pulse),
        .hit           (hit_l2),
        .miss          (miss_l2),
        .data_ready    (l2_data_ready),
        .addr_out      (addr_ram),
        .data_out      (l2_data_out)
    );

    // Fatiador de Blocos: Compatibiliza as capacidades das caches.
    // A L2 entrega um bloco gigante de 64 bytes (512 bits). A L1 só cabe 32 bytes (256 bits).
    // O bit addr[5] define se a L1 precisa da metade superior ou inferior do bloco.
    wire [255:0] l1i_fill = addr_miss_l1i[5] ? l2_data_out[511:256] : l2_data_out[255:0];
    wire [255:0] l1d_fill = addr_miss_l1d[5] ? l2_data_out[511:256] : l2_data_out[255:0];

    // Cache L1 exclusiva para código
    cache_l1_lru L1_Instrucoes (
        .clk        (clk),
        .rst        (rst),
        .req        (req_instrucao),
        .addr       (addr_instrucao),
        .la_addr    (la_addr),
        .la_valid   (la_valid),
        .data_in    (l1i_fill),
        .fill_ready (l2_data_ready), // Só absorve o bloco quando a L2 sinaliza que é seguro
        .inv_req    (req_escrita),   // Gatilho para apagar a linha se houver um store neste endereço
        .inv_addr   (addr_escrita),
        .hit        (hit_instrucao),
        .miss       (miss_l1i),
        .addr_out   (addr_miss_l1i),
        .data_out   (dado_instrucao)
    );

    // Cache L1 exclusiva para variáveis e dados da aplicação
    cache_l1_lru L1_Dados (
        .clk        (clk),
        .rst        (rst),
        .req        (req_dado),
        .addr       (addr_dado),
        .la_addr    (la_addr),
        .la_valid   (la_valid),
        .data_in    (l1d_fill),
        .fill_ready (l2_data_ready),
        .inv_req    (req_escrita),
        .inv_addr   (addr_escrita),
        .hit        (hit_dado),
        .miss       (miss_l1d),
        .addr_out   (addr_miss_l1d),
        .data_out   (dado_leitura)
    );
endmodule