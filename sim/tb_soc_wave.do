onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {=== SISTEMA ===}
add wave -noupdate -color white /tb_soc/clk
add wave -noupdate -color white /tb_soc/rst
add wave -noupdate -divider {=== PROCESSADOR ===}
add wave -noupdate -color cyan /tb_soc/dut/cpu_mem_valid
add wave -noupdate -color cyan /tb_soc/dut/cpu_mem_ready
add wave -noupdate -color cyan -radix hexadecimal /tb_soc/dut/cpu_mem_addr
add wave -noupdate -color cyan -radix hexadecimal /tb_soc/dut/cpu_mem_wdata
add wave -noupdate -divider {=== CACHE L1 ===}
add wave -noupdate -color green /tb_soc/dut/sistema_cache/hit_instrucao
add wave -noupdate -color red /tb_soc/dut/sistema_cache/miss_l1i
add wave -noupdate -color green /tb_soc/dut/sistema_cache/hit_dado
add wave -noupdate -color red /tb_soc/dut/sistema_cache/miss_l1d
add wave -noupdate -color yellow /tb_soc/dut/sistema_cache/req_escrita
add wave -noupdate -divider {=== CACHE L2 (AIRA) ===}
add wave -noupdate -color green /tb_soc/dut/sistema_cache/L2_Unificada/hit
add wave -noupdate -color red /tb_soc/dut/sistema_cache/L2_Unificada/miss
add wave -noupdate -color orange -radix binary /tb_soc/dut/sistema_cache/L2_Unificada/way_hits
add wave -noupdate -divider {=== TRIBUNAL AIRA ===}
add wave -noupdate -color magenta -radix unsigned /tb_soc/dut/sistema_cache/L2_Unificada/inteligencia/victim_way
add wave -noupdate -color magenta -radix unsigned /tb_soc/dut/sistema_cache/L2_Unificada/inteligencia/freq
add wave -noupdate -color magenta -radix unsigned /tb_soc/dut/sistema_cache/L2_Unificada/inteligencia/idade
add wave -noupdate -divider {=== CALCULOS E SCORES ===}
add wave -noupdate -color yellow -radix decimal /tb_soc/dut/sistema_cache/L2_Unificada/inteligencia/score
add wave -noupdate -color yellow -radix decimal /tb_soc/dut/sistema_cache/L2_Unificada/inteligencia/sB1_val
add wave -noupdate -color yellow -radix decimal /tb_soc/dut/sistema_cache/L2_Unificada/inteligencia/min01
add wave -noupdate -color yellow -radix decimal /tb_soc/dut/sistema_cache/L2_Unificada/inteligencia/min23
add wave -noupdate -divider {=== MEMORIA RAM ===}
add wave -noupdate -color blue /tb_soc/dut/sistema_cache/RAM/we
add wave -noupdate -color blue /tb_soc/dut/sistema_cache/RAM/ram_data_ready
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 160
configure wave -valuecolwidth 86
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {400984 ps}
