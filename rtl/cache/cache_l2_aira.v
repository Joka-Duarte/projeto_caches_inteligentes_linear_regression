`timescale 1ns/1ps
// Cache L2 Unificada (32KB, 8 vias)
// Guarda blocos maiores (64 bytes) e usa o algoritmo AIRA para gerenciar as vias.
// Faz a ponte entre as caches L1 mais rápidas e a lenta memória RAM principal.

module cache_l2_aira (
    input  wire          clk,
    input  wire          rst,
    input  wire          req,
    input  wire [31:0]   addr,
    
    // Recebe blocos grandes de 512 bits diretamente da RAM
    input  wire [511:0]  ram_data_in,
    input  wire          ram_data_ready, // Pulso avisando que a RAM entregou o bloco
    
    output wire          hit,
    output wire          miss,
    output wire          data_ready,     // Avisa a L1 que ela pode puxar o dado
    output wire [31:0]   addr_out,
    output wire [511:0]  data_out        // Bloco de 64 bytes que vai para a L1
);

    // Decomposição do endereço para a geometria da L2 (blocos maiores)
    wire [19:0] tag_in = addr[31:12]; // 20 bits de Tag
    wire [5:0]  index  = addr[11:6];  // 6 bits de índice

    wire [19:0]  tag_out_v   [0:7];
    wire         valid_out_v [0:7];
    wire [511:0] data_out_v  [0:7];
    
    wire [7:0]   valid_bus;
    wire [7:0]   way_hits;

    // Varre as 8 vias ao mesmo tempo para achar quem tem a tag certa
    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : cmp
            assign way_hits[g]  = valid_out_v[g] & (tag_out_v[g] == tag_in);
            assign valid_bus[g] = valid_out_v[g];
        end
    endgenerate

    assign hit      = req & (|way_hits);
    assign miss     = req & ~(|way_hits);
    assign addr_out = addr;

    // Mux em cascata: escolhe o barramento de dados da via que sinalizou hit
    assign data_out = way_hits[7] ? data_out_v[7] :
                      way_hits[6] ? data_out_v[6] :
                      way_hits[5] ? data_out_v[5] :
                      way_hits[4] ? data_out_v[4] :
                      way_hits[3] ? data_out_v[3] :
                      way_hits[2] ? data_out_v[2] :
                      way_hits[1] ? data_out_v[1] : data_out_v[0];

    // Converte os sinais de hit independentes para um índice numérico de 3 bits (0 a 7)
    wire [2:0] hit_way_idx =
        way_hits[7] ? 3'd7 : way_hits[6] ? 3'd6 :
        way_hits[5] ? 3'd5 : way_hits[4] ? 3'd4 :
        way_hits[3] ? 3'd3 : way_hits[2] ? 3'd2 :
        way_hits[1] ? 3'd1 : 3'd0;

    // Módulo AIRA que decide qual das 8 vias vai perder seu dado durante um miss
    wire [2:0] victim_way;
    aira_controller inteligencia (
        .clk(clk), .rst(rst),
        .hit(hit), .miss(miss),
        .hit_way(hit_way_idx),
        .valid(valid_bus),
        .victim_way(victim_way)
    );

    // Controle de temporização para liberar a leitura da L1
    wire any_we;
    reg  hit_d1;
    reg  was_filled_r;
    
    always @(posedge clk) begin
        if (rst) begin
            hit_d1       <= 1'b0;
            was_filled_r <= 1'b0;
        end else begin
            // Atrasa o hit em 1 ciclo para dar tempo da BRAM entregar a leitura interna
            hit_d1       <= hit;
            // Memoriza se uma escrita vinda da RAM acabou de acontecer no ciclo passado
            was_filled_r <= any_we;
        end
    end

    // A L2 avisa a L1 que o dado está pronto se a BRAM terminou de ler (hit passado) 
    // ou se o dado fresquinho acabou de chegar da RAM (write-forward)
    assign data_ready = was_filled_r | hit_d1;

    wire [7:0] we_vec;
    assign any_we = |we_vec;

    // Instanciação das 8 estruturas físicas de armazenamento da cache
    generate
        for (g = 0; g < 8; g = g + 1) begin : ways
            // Só deixa gravar na L2 se for miss, a RAM estiver pronta, e o AIRA escolheu esta via
            assign we_vec[g] = miss & ram_data_ready & (victim_way == g[2:0]);

            cache_way #(.DATA_BITS(512), .SETS(64), .INDEX_BITS(6), .TAG_BITS(20)) memoria_via (
                .clk(clk), .rst(rst),
                .write_enable(we_vec[g]),
                .invalidate(1'b0),     // A L2 trabalha como write-through e não invalida no store
                .index(index),
                .la_index(index),      // Pré-leitura engatilhada diretamente pela detecção do hit da L2
                .la_valid(hit),        
                .tag_in(tag_in),
                .data_in(ram_data_in),
                .tag_out(tag_out_v[g]),
                .valid_out(valid_out_v[g]),
                .data_out(data_out_v[g])
            );
        end
    endgenerate
endmodule