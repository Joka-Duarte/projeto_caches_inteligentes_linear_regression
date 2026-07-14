`timescale 1ns/1ps
// Teste para medir as estatísticas e as taxas de acerto do controlador AIRA.
// Esse arquivo "desliga" a CPU e se conecta direto nas memórias, lendo um 
// histórico em texto (.txt) com milhares de requisições de um programa real.

module tb_trace ();
    reg        clk, rst;
    reg        req_instrucao, req_dado;
    reg [31:0] addr_instrucao, addr_dado;

    wire [31:0] dado_instrucao, dado_leitura;
    wire        hit_instrucao, hit_dado, miss_l2, ram_ready_out;

    hierarquia_memoria uut (
        .clk           (clk), .rst(rst),
        .req_instrucao (req_instrucao),
        .addr_instrucao(addr_instrucao),
        .dado_instrucao(dado_instrucao),
        .hit_instrucao (hit_instrucao),
        .req_dado      (req_dado),
        .addr_dado     (addr_dado),
        .dado_leitura  (dado_leitura),
        .hit_dado      (hit_dado),
        .la_valid      (1'b0),
        .la_addr       (32'd0),
        .req_escrita   (1'b0),
        .addr_escrita  (32'd0),
        .wstrb         (4'd0),
        .wdata         (32'd0),
        .miss_l2       (miss_l2),
        .ram_ready_out (ram_ready_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Contadores para o cálculo final do benchmark
    integer total_acessos = 0, hits_l1 = 0, hits_l2 = 0, misses_ram = 0;
    integer file, r, guard;
    reg [7:0] tipo_acesso;
    reg [31:0] trace_addr;
    reg cur_hit, cur_miss_l2;

    initial begin
        rst = 1; req_instrucao = 0; req_dado = 0;
        addr_instrucao = 0; addr_dado = 0;
        repeat(4) @(posedge clk);
        rst = 0; @(posedge clk);

        // Abre o arquivo de texto para puxar o histórico
        file = $fopen("C:/chonga/trace_teste_aira.txt", "r");
        if (file == 0) begin $display("ERRO: trace.txt nao encontrado."); $finish; end

        $display("=========================================");
        $display("  Simulacao AIRA – iniciando trace...   ");
        $display("=========================================");
        
        while (!$feof(file)) begin
            r = $fscanf(file, " %c %x", tipo_acesso, trace_addr);
            if (r == 2) begin
                @(posedge clk);
                // Direciona a requisição lida para o barramento correto
                if (tipo_acesso == "I" || tipo_acesso == "i") begin
                    req_instrucao = 1'b1; addr_instrucao = trace_addr; req_dado = 1'b0;
                end else begin
                    req_dado = 1'b1; addr_dado = trace_addr; req_instrucao = 1'b0;
                end

                // Fica em estado de espera até a memória responder com o dado.
                // Usa um timeout (guard) para abortar e não deixar a simulação congelar.
                guard = 0;
                begin : wait_ready
                    forever begin
                        @(posedge clk);
                        guard = guard + 1;
                        if ((tipo_acesso=="I"||tipo_acesso=="i") ? hit_instrucao : hit_dado)
                            disable wait_ready;
                        if (guard >= 40) disable wait_ready; // timeout
                    end
                end

                // Amostragem: Classifica o resultado da requisição após a resposta
                #1;
                total_acessos = total_acessos + 1;
                cur_hit     = (tipo_acesso == "I" || tipo_acesso == "i") ? hit_instrucao : hit_dado;
                cur_miss_l2 = miss_l2;

                if (cur_hit && guard == 0)
                    hits_l1 = hits_l1 + 1;           // Acesso instantâneo: Dado estava na L1
                else if (cur_hit && !cur_miss_l2)
                    hits_l2 = hits_l2 + 1;           // Demorou, mas L2 deu hit: Dado estava na L2
                else
                    misses_ram = misses_ram + 1;     // L2 deu miss: Buscou na RAM principal

                req_dado = 0; req_instrucao = 0;
                #4;
            end
        end

        $fclose(file);
        
        // Exibe o cálculo consolidado das taxas de acerto
        $display("\n=========================================");
        $display("   RESULTADOS  – AIRA L2 Cache");
        $display("=========================================");
        $display(" Total de acessos  : %0d", total_acessos);
        $display(" Hits na L1        : %0d", hits_l1);
        $display(" Hits na L2 (AIRA) : %0d", hits_l2);
        $display(" Misses (RAM)      : %0d", misses_ram);
        if (total_acessos > 0) begin
            $display(" Taxa Hit L1       : %0d %%", (hits_l1*100)/total_acessos);
            $display(" Taxa Hit L1+L2    : %0d %%", ((hits_l1+hits_l2)*100)/total_acessos);
            $display(" Taxa Miss global  : %0d %%", (misses_ram*100)/total_acessos);
        end
        $display("=========================================");
        $stop;
    end
endmodule