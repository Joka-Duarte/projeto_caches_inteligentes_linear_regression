`timescale 1ns/1ps
// Cache L1 (Instruções ou Dados)
// Capacidade de 4KB, 2 vias, algoritmo LRU. Trabalha com blocos de 32 bytes.
// Possui leitura antecipada (look-ahead) e proteção contra dados obsoletos (invalidação).

module cache_l1_lru (
    input  wire         clk,
    input  wire         rst,
    input  wire         req,
    input  wire [31:0]  addr,
    
    // Antecipação de leitura vinda da CPU. Prepara a memória 1 ciclo antes de precisar.
    input  wire [31:0]  la_addr,
    input  wire         la_valid,
    
    // Entrada de 32 bytes (256 bits) vindos da cache L2
    input  wire [255:0] data_in,
    // Libera a gravação na L1 apenas quando a L2 avisa que o dado já chegou
    input  wire         fill_ready,
    
    // Sinais para invalidar uma linha caso a CPU faça uma escrita (store) nela
    input  wire         inv_req,
    input  wire [31:0]  inv_addr,
    
    output wire         hit,
    output wire         miss,
    output wire [31:0]  addr_out,
    output wire [31:0]  data_out // Entrega apenas a palavra de 32 bits pedida pela CPU
);

    // Decomposição do endereço para blocos de 32 bytes
    wire [20:0] tag_in  = addr[31:11]; // 21 bits de Tag
    wire [5:0]  index   = addr[10:5];  // 6 bits para achar um dos 64 conjuntos
    wire [2:0]  woff    = addr[4:2];   // Offset para achar a palavra exata dentro do bloco
    
    // Decomposição para a leitura antecipada e para a invalidação
    wire [5:0]  la_idx  = la_addr[10:5];
    wire [5:0]  inv_idx = inv_addr[10:5];
    wire [20:0] inv_tag = inv_addr[31:11];

    // Barramentos de saída lidos das vias
    wire [20:0]  tag_out_v  [0:1];
    wire         valid_out_v[0:1];
    wire [255:0] data_out_v [0:1];

    // Detecção de acerto (Hit). A via dá hit se o dado for válido e a tag bater.
    wire [1:0] way_hits;
    assign way_hits[0] = valid_out_v[0] & (tag_out_v[0] == tag_in);
    assign way_hits[1] = valid_out_v[1] & (tag_out_v[1] == tag_in);

    assign hit      = req & (way_hits[0] | way_hits[1]);
    assign miss     = req & ~(way_hits[0] | way_hits[1]);
    assign addr_out = addr;

    // Seleciona o bloco da via que acertou e extrai só a palavra de 32 bits solicitada
    wire [255:0] bloco_sel = way_hits[1] ? data_out_v[1] : data_out_v[0];
    assign data_out = bloco_sel[woff*32 +: 32];

    // Lógica para decidir qual via recebe um novo bloco da L2 (usando o bit LRU)
    reg lru_bit [0:63];
    wire we_0 = miss & fill_ready & ~lru_bit[index];
    wire we_1 = miss & fill_ready &  lru_bit[index];

    // Checa se o endereço que a CPU está alterando (store) existe na cache para poder invalidá-lo
    wire inv_way0 = inv_req & valid_out_v[0] & (tag_out_v[0] == inv_tag);
    wire inv_way1 = inv_req & valid_out_v[1] & (tag_out_v[1] == inv_tag);

    // Atualiza a política LRU. O bit aponta sempre para a via que NÃO foi acessada no último hit.
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 64; i = i + 1)
                lru_bit[i] <= 1'b0;
        end else if (hit) begin
            lru_bit[index] <= way_hits[0] ? 1'b1 : 1'b0;
        end
    end

    // Instanciação física das duas vias usando o módulo parametrizado
    cache_way #(.DATA_BITS(256), .SETS(64), .INDEX_BITS(6), .TAG_BITS(21)) via0 (
        .clk(clk), .rst(rst),
        .write_enable(we_0),
        .invalidate(inv_way0),
        .index(index), .la_index(la_idx), .la_valid(la_valid),
        .tag_in(tag_in), .data_in(data_in),
        .tag_out(tag_out_v[0]), .valid_out(valid_out_v[0]), .data_out(data_out_v[0])
    );
    
    cache_way #(.DATA_BITS(256), .SETS(64), .INDEX_BITS(6), .TAG_BITS(21)) via1 (
        .clk(clk), .rst(rst),
        .write_enable(we_1),
        .invalidate(inv_way1),
        .index(index), .la_index(la_idx), .la_valid(la_valid),
        .tag_in(tag_in), .data_in(data_in),
        .tag_out(tag_out_v[1]), .valid_out(valid_out_v[1]), .data_out(data_out_v[1])
    );
endmodule