`timescale 1ns/1ps
// Módulo Top-Level. É a placa-mãe do projeto, que junta a CPU RISC-V com a 
// hierarquia de caches e faz a conversão do protocolo de comunicação.

module soc_top (
    input  wire clk,
    input  wire rst,
    // Sinais externos para que as ferramentas de otimização do FPGA não deletem 
    // lógicas internas achando que elas não fazem nada.
    output wire        miss_l2_ext,
    output wire [31:0] addr_ram_ext,
    output wire        trap            
);

    // Sinais de interface brutos que saem/entram da CPU
    wire        cpu_mem_valid;
    wire        cpu_mem_instr;
    wire [31:0] cpu_mem_addr;
    wire [31:0] cpu_mem_wdata;
    wire [ 3:0] cpu_mem_wstrb;
    
    // Sinais do recurso de antecipação (look-ahead)
    wire        cpu_la_read;
    wire [31:0] cpu_la_addr;

    reg         cpu_mem_ready;
    reg  [31:0] cpu_mem_rdata;

    // Fios que transportam os sinais das memórias
    wire [31:0] dado_instrucao;
    wire [31:0] dado_leitura;
    wire        hit_instrucao;
    wire        hit_dado;
    wire        miss_l2;
    wire        ram_ready_out;

    assign miss_l2_ext  = miss_l2;
    assign addr_ram_ext = 32'd0;

    // Decodifica a intenção da CPU para separar leituras e escritas nas L1
    wire is_write = cpu_mem_valid & (|cpu_mem_wstrb);
    wire is_read  = cpu_mem_valid & ~(|cpu_mem_wstrb);
    wire req_l1i  = is_read &  cpu_mem_instr;
    wire req_l1d  = is_read & ~cpu_mem_instr;

    // Monta o subsistema completo de memórias
    hierarquia_memoria sistema_cache (
        .clk             (clk),
        .rst             (rst),
        .req_instrucao   (req_l1i),
        .addr_instrucao  (cpu_mem_addr),
        .dado_instrucao  (dado_instrucao),
        .hit_instrucao   (hit_instrucao),
        .req_dado        (req_l1d),
        .addr_dado       (cpu_mem_addr),
        .dado_leitura    (dado_leitura),
        .hit_dado        (hit_dado),
        .la_valid        (cpu_la_read),
        .la_addr         (cpu_la_addr),
        .req_escrita     (is_write),
        .addr_escrita    (cpu_mem_addr),
        .wstrb           (cpu_mem_wstrb),
        .wdata           (cpu_mem_wdata),
        .miss_l2         (miss_l2),
        .ram_ready_out   (ram_ready_out)
    );

    // Semáforo da Interface de Memória (O cérebro do SoC).
    // O protocolo PicoRV32 trava a CPU até que `mem_ready` retorne sinal alto.
    always @(*) begin
        cpu_mem_ready = 1'b0;
        cpu_mem_rdata = 32'd0;

        if (cpu_mem_valid) begin
            if (is_write) begin
                // Como a escrita vai direto pra RAM, a CPU é liberada instantaneamente (sem stall)
                cpu_mem_ready = 1'b1;
            end else if (cpu_mem_instr) begin
                // Libera a CPU apenas quando a Cache de Instrução encontrar o bloco
                cpu_mem_ready = hit_instrucao;
                cpu_mem_rdata = dado_instrucao;
            end else begin
                // Libera a CPU apenas quando a Cache de Dados encontrar o bloco
                cpu_mem_ready = hit_dado;
                cpu_mem_rdata = dado_leitura;
            end
        end
    end

    // Instancia o núcleo do processador RISC-V. 
    // Módulos pesados (mul/div/coprocessador) foram desligados para economizar espaço no FPGA.
    picorv32 #(
        .ENABLE_COUNTERS (1),
        .ENABLE_MUL      (0),
        .ENABLE_DIV      (0),
        .CATCH_MISALIGN  (1),
        .CATCH_ILLINSN   (1)
    ) cpu (
        .clk        (clk),
        .resetn     (~rst), // Corrige a polaridade do reset original que é ativo em nível baixo
        .trap       (trap),
        .mem_valid  (cpu_mem_valid),
        .mem_instr  (cpu_mem_instr),
        .mem_ready  (cpu_mem_ready),
        .mem_addr   (cpu_mem_addr),
        .mem_wdata  (cpu_mem_wdata),
        .mem_wstrb  (cpu_mem_wstrb),
        .mem_rdata  (cpu_mem_rdata),
        .mem_la_read (cpu_la_read),
        .mem_la_write(),
        .mem_la_addr (cpu_la_addr),
        .mem_la_wdata(),
        .mem_la_wstrb(),
        .pcpi_wr    (1'b0),
        .pcpi_rd    (32'd0),
        .pcpi_wait  (1'b0),
        .pcpi_ready (1'b0),
        .irq        (32'd0)
    );
endmodule