`timescale 1ns/1ps
// Módulo de armazenamento genérico. Atua como molde para as vias da L1 e da L2.
// Recebe os parâmetros de tamanho e se adapta. Usa atributos especiais para que
// o compilador do Quartus mapeie os dados para os blocos físicos de RAM do chip.

module cache_way #(
    parameter DATA_BITS  = 512,
    parameter SETS       = 64,
    parameter INDEX_BITS = 6,
    parameter TAG_BITS   = 20
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   write_enable, // Autoriza preenchimento (fill) de um bloco novo
    input  wire                   invalidate,   // Comando para apagar (invalidar) a linha
    input  wire [INDEX_BITS-1:0]  index,        // Índice normal de acesso
    input  wire [INDEX_BITS-1:0]  la_index,     // Índice de antecipação (look-ahead)
    input  wire                   la_valid,     // Habilita a leitura antecipada
    input  wire [TAG_BITS-1:0]    tag_in,
    input  wire [DATA_BITS-1:0]   data_in,
    
    output wire [TAG_BITS-1:0]    tag_out,      // Saída rápida/combinacional da tag
    output wire                   valid_out,    
    output wire [DATA_BITS-1:0]   data_out      // Saída síncrona dos dados
);

    // Memórias para Tags e Validade. Permitem leitura instantânea.
    reg [TAG_BITS-1:0] ram_tags   [0:SETS-1];
    reg                valid_bits [0:SETS-1];
    
    // Matriz de dados. A diretiva "ramstyle" orienta o Quartus a inferir blocos M9K/MLAB
    // dedicados, evitando o desperdício de elementos lógicos padrão.
    (* ramstyle = "AUTO" *) reg [DATA_BITS-1:0] ram_dados [0:SETS-1];

    assign tag_out   = ram_tags[index];
    assign valid_out = valid_bits[index];

    integer i;
    
    // Controle da tag e do bit de validade
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < SETS; i = i + 1)
                valid_bits[i] <= 1'b0;
        end else begin
            if (write_enable) begin
                ram_tags[index]   <= tag_in;
                valid_bits[index] <= 1'b1; // Linha agora possui dados úteis
            end else if (invalidate) begin
                valid_bits[index] <= 1'b0; // CPU modificou a RAM direto, apaga o dado velho daqui
            end
        end
    end

    // Controle de Escrita e Leitura da memória de dados principal
    reg [DATA_BITS-1:0] ram_read_data;
    always @(posedge clk) begin
        if (write_enable) begin
            ram_dados[index] <= data_in;
        end
        if (la_valid) begin
            // Inicia a leitura do próximo acesso usando o endereço antecipado
            ram_read_data <= ram_dados[la_index];
        end
    end

    // Registrador de Bypass (Write-Forwarding). 
    // Resolve o problema de tentar ler um dado no mesmo ciclo em que ele está sendo gravado.
    // Em vez de esperar 1 ciclo da RAM, salva o dado que acabou de entrar e repassa direto.
    reg [DATA_BITS-1:0] bypass_data;
    reg                 use_bypass;
    
    always @(posedge clk) begin
        if (rst) begin
            use_bypass <= 1'b0;
        end else if (write_enable) begin
            bypass_data <= data_in; // Salva uma cópia do bloco novo
            use_bypass  <= 1'b1;    // Sinaliza que vai usar a cópia
        end else if (la_valid) begin
            use_bypass  <= 1'b0;    // Acesso normal, volta a ler da memória real
        end
    end

    // Seleciona se a saída manda o dado normal da memória ou o dado rápido do bypass
    assign data_out = use_bypass ? bypass_data : ram_read_data;
endmodule