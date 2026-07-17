onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {=== SISTEMA ===}
add wave -noupdate -color white /tb_trace/clk
add wave -noupdate -color white /tb_trace/rst
add wave -noupdate -divider {=== ACESSOS DO TRACE ===}
add wave -noupdate -color cyan /tb_trace/req_instrucao
add wave -noupdate -color cyan /tb_trace/req_dado
add wave -noupdate -color cyan -radix hexadecimal /tb_trace/addr_instrucao
add wave -noupdate -color cyan -radix hexadecimal /tb_trace/addr_dado
add wave -noupdate -divider {=== CACHES L1 ===}
add wave -noupdate -color green /tb_trace/hit_instrucao
add wave -noupdate -color green /tb_trace/hit_dado
add wave -noupdate -color red /tb_trace/uut/miss_l1i
add wave -noupdate -color red /tb_trace/uut/miss_l1d
add wave -noupdate -divider {=== CACHE L2 ===}
add wave -noupdate -color green /tb_trace/uut/L2_Unificada/hit
add wave -noupdate -color red /tb_trace/uut/L2_Unificada/miss
add wave -noupdate -color orange -radix binary /tb_trace/uut/L2_Unificada/way_hits
add wave -noupdate -divider {=== STATUS DAS VIAS ===}
add wave -noupdate -color magenta -radix unsigned /tb_trace/uut/L2_Unificada/inteligencia/freq
add wave -noupdate -color magenta -radix unsigned /tb_trace/uut/L2_Unificada/inteligencia/idade
add wave -noupdate -divider {=== TORNEIO PIPELINE ===}
add wave -noupdate -color yellow -radix decimal /tb_trace/uut/L2_Unificada/inteligencia/score
add wave -noupdate -color yellow -radix decimal /tb_trace/uut/L2_Unificada/inteligencia/sB1_val
add wave -noupdate -color yellow -radix decimal /tb_trace/uut/L2_Unificada/inteligencia/min01
add wave -noupdate -color yellow -radix decimal /tb_trace/uut/L2_Unificada/inteligencia/min23
add wave -noupdate -color red -radix unsigned /tb_trace/uut/L2_Unificada/inteligencia/victim_way
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 160
configure wave -valuecolwidth 100
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
WaveRestoreZoom {0 ps} {993850 ps}
