`timescale 1ns/1ps
// Controlador AIRA (Regressão Linear)
// Responsável por escolher qual bloco será ejetado da cache L2.
// Ele calcula o score de cada via: (Frequência * 4) - Idade.
// A via que tiver o menor score (menos usada e mais velha) é a escolhida para sair.
// O cálculo é feito em um pipeline de 2 estágios para não atrasar o clock do processador.

module aira_controller (
    input  wire       clk,
    input  wire       rst,
    input  wire       hit,
    input  wire       miss,
    input  wire [2:0] hit_way,
    input  wire [7:0] valid,
    output wire [2:0] victim_way
);
    reg [7:0] freq  [0:7];
    reg [7:0] idade [0:7];

    // Calcula o score de cada via instantaneamente (combinacional, 15 bits com sinal)
    wire signed [14:0] score [0:7];
    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : calc
            // Se a via estiver vazia (!valid), ela ganha um score muito negativo (-1024) 
            // para ter prioridade máxima de saída. Senão, aplica a fórmula.
            assign score[g] = (!valid[g]) ?
                (-15'sd1024) :
                ($signed({1'b0, freq[g]}) <<< 2) - $signed({1'b0, idade[g]});
        end
    endgenerate

    // Estágio 1 do pipeline: Torneio de pares síncrono.
    // Salva o menor score e o índice do vencedor de cada dupla para o próximo ciclo.
    reg signed [14:0] sB1_val [0:3];
    reg        [2:0]  sB1_idx [0:3];
    
    always @(posedge clk) begin
        if (rst) begin
            // Limpa o pipeline no reset para evitar decisões baseadas em lixo de memória
            sB1_val[0] <= -15'sd1024; sB1_idx[0] <= 3'd0;
            sB1_val[1] <= -15'sd1024; sB1_idx[1] <= 3'd2;
            sB1_val[2] <= -15'sd1024; sB1_idx[2] <= 3'd4;
            sB1_val[3] <= -15'sd1024; sB1_idx[3] <= 3'd6;
        end else begin
            // Compara as vias 0 e 1
            if (score[0] <= score[1]) begin sB1_val[0] <= score[0]; sB1_idx[0] <= 3'd0; end
            else                      begin sB1_val[0] <= score[1]; sB1_idx[0] <= 3'd1; end
            // Compara as vias 2 e 3
            if (score[2] <= score[3]) begin sB1_val[1] <= score[2]; sB1_idx[1] <= 3'd2; end
            else                      begin sB1_val[1] <= score[3]; sB1_idx[1] <= 3'd3; end
            // Compara as vias 4 e 5
            if (score[4] <= score[5]) begin sB1_val[2] <= score[4]; sB1_idx[2] <= 3'd4; end
            else                      begin sB1_val[2] <= score[5]; sB1_idx[2] <= 3'd5; end
            // Compara as vias 6 e 7
            if (score[6] <= score[7]) begin sB1_val[3] <= score[6]; sB1_idx[3] <= 3'd6; end
            else                      begin sB1_val[3] <= score[7]; sB1_idx[3] <= 3'd7; end
        end
    end

    // Estágio 2: Redução final (combinacional).
    // Compara os 4 semifinalistas para encontrar a vítima final deste ciclo.
    wire signed [14:0] min01 = (sB1_val[0] <= sB1_val[1]) ? sB1_val[0] : sB1_val[1];
    wire        [2:0]  idx01 = (sB1_val[0] <= sB1_val[1]) ? sB1_idx[0] : sB1_idx[1];
    wire signed [14:0] min23 = (sB1_val[2] <= sB1_val[3]) ? sB1_val[2] : sB1_val[3];
    wire        [2:0]  idx23 = (sB1_val[2] <= sB1_val[3]) ? sB1_idx[2] : sB1_idx[3];
    
    assign victim_way = (min01 <= min23) ? idx01 : idx23;

    // Atualiza o histórico de uso das vias (síncrono)
    integer j;
    always @(posedge clk) begin
        if (rst) begin
            for (j = 0; j < 8; j = j + 1) begin
                freq [j] <= 8'd1;
                idade[j] <= 8'd0;
            end
        end else if (hit) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (j == hit_way) begin
                    // A via que sofreu o hit zera a idade e aumenta a frequência
                    // O valor é limitado a 255 para o registrador de 8 bits não estourar (overflow)
                    freq [j] <= (freq[j] < 8'd255) ? freq[j] + 8'd1 : 8'd255;
                    idade[j] <= 8'd0;
                end else begin
                    // As outras vias ficam mais velhas (também satura em 255)
                    idade[j] <= (idade[j] < 8'd255) ? idade[j] + 8'd1 : 8'd255;
                end
            end
        end else if (miss) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (j == victim_way) begin
                    // A via ejetada recebe um dado novo, então reiniciamos as métricas dela
                    freq [j] <= 8'd1;
                    idade[j] <= 8'd0;
                end else begin
                    // As vias que sobreviveram ficam mais velhas
                    idade[j] <= (idade[j] < 8'd255) ? idade[j] + 8'd1 : 8'd255;
                end
            end
        end
    end
endmodule