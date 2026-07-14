`timescale 1ns/1ps
// Teste de simulação inicial (Smoke Test).
// O objetivo é injetar um código inútil e ver se a CPU consegue operar
// toda a hierarquia de caches e memória RAM sem entrar em curto ou travar.

module tb_soc;
    reg  clk, rst;
    wire miss_l2_ext;
    wire [31:0] addr_ram_ext;
    wire trap;

    soc_top dut (
        .clk(clk), .rst(rst),
        .miss_l2_ext(miss_l2_ext),
        .addr_ram_ext(addr_ram_ext),
        .trap(trap)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer i;
    initial begin
        // Povoa a RAM com o comando NOP (No Operation), forçando a CPU a ler continuamente
        for (i = 0; i < 1024; i = i + 1)
            dut.sistema_cache.RAM.mem[i] = {16{32'h00000013}};

        rst = 1;
        repeat(4) @(posedge clk);
        rst = 0;
        $display("Reset liberado em t=%0t ns", $time);

        repeat(400) begin
            @(posedge clk);
            // Mostra no console tudo que a CPU está pedindo e se a memória já respondeu
            if (dut.cpu_mem_valid)
                $display("t=%5t | instr=%b addr=%08h ready=%b miss_l2=%b trap=%b",
                    $time, dut.cpu_mem_instr, dut.cpu_mem_addr,
                    dut.cpu_mem_ready, miss_l2_ext, trap);

            // Verifica se a CPU reportou uma exceção fatal
            if (trap) begin
                $display("TRAP detectado em t=%0t — CPU em exceção", $time);
                $stop;
            end
        end

        $display("\n=== Smoke test concluido ===");
        $stop;
    end
endmodule