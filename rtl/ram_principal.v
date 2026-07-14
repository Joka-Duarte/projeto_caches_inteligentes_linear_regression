`timescale 1ns/1ps
// Módulo que simula o comportamento de uma Memória RAM externa.
// Possui uma porta de leitura que aplica uma latência de espera para imitar a lentidão
// do acesso fora do chip, e uma porta de escrita que grava imediatamente na memória.

module ram_principal (
    input  wire          clk,
    input  wire          rst,
    
    // Canal de Leitura (Chamado quando a L2 sofre um miss)
    input  wire          req,
    input  wire [31:0]   addr,
    output reg  [511:0]  data_out,
    output reg           ready,
    output reg           ram_data_ready, // Pulso de sincronização de 1 ciclo
    
    // Canal direto de Escrita byte a byte (vinda dos stores da CPU)
    input  wire          we,
    input  wire [3:0]    wstrb,
    input  wire [31:0]   wdata,
    input  wire [31:0]   waddr
);
    parameter LATENCIA_RAM = 10; // Ciclos configuráveis de punição para um miss L2

    // Matriz de armazenamento físico simplificada para a simulação (64 blocos de 64 bytes)
    reg [511:0] mem [0:63];
    
    // Enche a memória com dados sequenciais fáceis de ler nas ondas do simulador
    integer idx;
    initial begin
        for (idx = 0; idx < 64; idx = idx + 1)
            mem[idx] = {16{idx[31:0]}};
    end

    // ---- Controle da Escrita Síncrona (Write-through) ----
    wire [9:0]  w_bloco = waddr[15:6];
    wire [3:0]  w_word  = waddr[5:2];

    integer b;
    always @(posedge clk) begin
        if (we) begin
            // Varre o bloco para alterar apenas a palavra (word) exata.
            // O wstrb (máscara) controla exatamente quais dos 4 bytes serão modificados.
            for (b = 0; b < 16; b = b + 1) begin
                if (b == w_word) begin
                    if (wstrb[0]) mem[w_bloco][b*32 +  0 +: 8] <= wdata[ 7: 0];
                    if (wstrb[1]) mem[w_bloco][b*32 +  8 +: 8] <= wdata[15: 8];
                    if (wstrb[2]) mem[w_bloco][b*32 + 16 +: 8] <= wdata[23:16];
                    if (wstrb[3]) mem[w_bloco][b*32 + 24 +: 8] <= wdata[31:24];
                end
            end
        end
    end

    // ---- Controle da Leitura com Atraso ----
    reg [3:0] ciclos_espera;
    always @(posedge clk) begin
        if (rst) begin
            ready          <= 1'b0;
            ram_data_ready <= 1'b0;
            ciclos_espera  <= 4'd0;
            data_out       <= 512'd0;
        end else begin
            ram_data_ready <= 1'b0; // Garante que o sinal seja um pulso curto

            if (req && !ready) begin
                if (ciclos_espera < LATENCIA_RAM - 1) begin
                    // Ainda contando o tempo...
                    ciclos_espera <= ciclos_espera + 4'd1;
                end else begin
                    // O tempo acabou. Lê o bloco da memória e devolve para a L2.
                    data_out       <= mem[addr[15:6]];
                    ready          <= 1'b1;
                    ram_data_ready <= 1'b1; // Dispara o pulso de confirmação
                    ciclos_espera  <= 4'd0;
                end
            end else if (!req) begin
                // Libera os barramentos quando a L2 encerra o pedido
                ready         <= 1'b0;
                ciclos_espera <= 4'd0;
            end
        end
    end
endmodule