import os
import time
from collections import OrderedDict
from typing import List, Tuple

# =====================================================================
# 1. BASELINE: CACHE SET-ASSOCIATIVE COM LRU (Para Comparação)
# =====================================================================
class CacheSetAssociativeLRU:
    def __init__(self, tamanho_bytes: int, tamanho_bloco: int, vias: int, nome: str):
        self.nome = nome
        self.tamanho_bloco = tamanho_bloco
        self.vias = vias
        self.num_conjuntos = (tamanho_bytes // tamanho_bloco) // vias
        self.conjuntos = [OrderedDict() for _ in range(self.num_conjuntos)]
        self.hits = 0
        self.misses = 0

    def acessar(self, endereco_byte: int) -> bool:
        endereco_bloco = endereco_byte // self.tamanho_bloco
        indice = endereco_bloco % self.num_conjuntos
        tag = endereco_bloco // self.num_conjuntos
        conjunto = self.conjuntos[indice]
        
        if tag in conjunto:
            self.hits += 1
            conjunto.move_to_end(tag)
            return True
        else:
            self.misses += 1
            if len(conjunto) >= self.vias:
                conjunto.popitem(last=False)
            conjunto[tag] = True
            return False

# =====================================================================
# 2. IA: CACHE SET-ASSOCIATIVE COM REGRESSÃO LINEAR (AIRA)
# =====================================================================
class BlocoAIRA:
    def __init__(self, tag: int):
        self.tag = tag
        self.frequencia = 1
        self.idade = 0

class CacheSetAssociativeAIRA:
    def __init__(self, tamanho_bytes: int, tamanho_bloco: int, vias: int, nome: str, w_freq: int, w_idade: int):
        self.nome = nome
        self.tamanho_bloco = tamanho_bloco
        self.vias = vias
        self.w_freq = w_freq
        self.w_idade = w_idade
        self.num_conjuntos = (tamanho_bytes // tamanho_bloco) // vias
        
        self.conjuntos = [{} for _ in range(self.num_conjuntos)]
        self.hits = 0
        self.misses = 0
        self.substituicoes = 0

    def acessar(self, endereco_byte: int) -> bool:
        endereco_bloco = endereco_byte // self.tamanho_bloco
        indice = endereco_bloco % self.num_conjuntos
        tag = endereco_bloco // self.num_conjuntos
        conjunto = self.conjuntos[indice]
        
        deu_hit = False
        bloco_acessado = None
        
        if tag in conjunto:
            self.hits += 1
            bloco_acessado = conjunto[tag]
            if bloco_acessado.frequencia < 255:
                bloco_acessado.frequencia += 1
            bloco_acessado.idade = 0
            deu_hit = True
        else:
            self.misses += 1
            if len(conjunto) >= self.vias:
                self._substituir(conjunto)
            bloco_acessado = BlocoAIRA(tag)
            conjunto[tag] = bloco_acessado
            deu_hit = False
            
        # O ENVELHECIMENTO DEVE OCORRER SEMPRE (Hit ou Miss)
        for via in conjunto.values():
            if via != bloco_acessado and via.idade < 255:
                via.idade += 1
                
        return deu_hit

    def _substituir(self, conjunto: dict):
        self.substituicoes += 1
        pior_score = float('inf')
        vitima_tag = None

        for tag, bloco in conjunto.items():
            idade = bloco.idade
            # calculo linear: O bloco com MENOR score será ejetado
            score = (self.w_freq * bloco.frequencia) + (self.w_idade * idade)
            
            if score < pior_score:
                pior_score = score
                vitima_tag = tag

        del conjunto[vitima_tag]

# =====================================================================
# 3. CONTROLADOR DA HIERARQUIA (Híbrida: L1=LRU, L2=AIRA)
# =====================================================================
class HierarquiaMemoria:
    def __init__(self, tipo_cache: str, w_freq: int = 0, w_idade: int = 0):
        if tipo_cache == "LRU":
            self.l1i = CacheSetAssociativeLRU(4096, 32, 2, "L1I")
            self.l1d = CacheSetAssociativeLRU(4096, 32, 2, "L1D")
            self.l2u = CacheSetAssociativeLRU(131072, 64, 8, "L2U")
        else:
            # ARQUITETURA HÍBRIDA: L1 continua LRU! AIRA atua apenas na L2.
            self.l1i = CacheSetAssociativeLRU(4096, 32, 2, "L1I")
            self.l1d = CacheSetAssociativeLRU(4096, 32, 2, "L1D")
            self.l2u = CacheSetAssociativeAIRA(131072, 64, 8, "L2U", w_freq, w_idade)
            
        self.tempo_global = 0

    def processar_acesso(self, tipo: str, endereco: int):
        self.tempo_global += 1
        hit_l1 = False
        if tipo == 'I':
            hit_l1 = self.l1i.acessar(endereco)
        elif tipo == 'D':
            hit_l1 = self.l1d.acessar(endereco)
        else:
            return   # ← ignora tipos desconhecidos no trace
        if not hit_l1:
            self.l2u.acessar(endereco)

    def obter_hit_rate(self, cache) -> float:
        total = cache.hits + cache.misses
        return (cache.hits / total * 100) if total > 0 else 0.0

    def calcular_ciclos_totais(self) -> int:
        l1_hits_totais = self.l1i.hits + self.l1d.hits
        l2_hits_totais = self.l2u.hits
        miss_l2_totais = self.l2u.misses
        
        ciclos_l1 = l1_hits_totais * 1
        ciclos_l2 = l2_hits_totais * 5
        ciclos_ram = miss_l2_totais * 100
        
        # PENALIDADE DA IA: 1 ciclos de hardware gastos pela árvore de comparadores toda vez que a L2 enche e precisamos ejetar um bloco.
        penalidade_ia = 0
        if isinstance(self.l2u, CacheSetAssociativeAIRA):
            penalidade_ia = self.l2u.substituicoes * 1
        
        return ciclos_l1 + ciclos_l2 + ciclos_ram + penalidade_ia

# =====================================================================
# 4. APP INTERATIVO
# =====================================================================
class SimuladorApp:
    def __init__(self):
        self.acessos = []
        self.arquivo_carregado = ""
        self.hr_lru_l2 = None 
        self.ciclos_lru = None  

    def carregar_trace(self, caminho_silencioso=""):
        if not caminho_silencioso:
            print("\n--- Carregar Arquivo de Trace ---")
            caminho = input("Digite o nome do arquivo (ex: trace_1.txt) ou pressione ENTER para padrão: ").strip()
            if not caminho:
                caminho = "trace_1.txt"
        else:
            caminho = caminho_silencioso

        diretorio_script = os.path.dirname(os.path.abspath(__file__))
        caminho_completo = os.path.join(diretorio_script, caminho)
            
        if not os.path.exists(caminho_completo):
            if not caminho_silencioso:
                print(f"❌ Erro: Arquivo '{caminho}' não encontrado.")
            return False

        self.acessos = []
        # Força o padrão UTF-8 do Linux mesmo rodando no Windows
        with open(caminho_completo, 'r', encoding='utf-8') as f:
            for linha in f:
                linha = linha.strip()
                if not linha or len(linha.split()) < 2: 
                    continue
                
                try:
                    p = linha.split()
                    # Lê SEMPRE em Base 16 (hexadecimal), independente de ter '0x' ou não
                    endereco_hex = int(p[1], 16) 
                    self.acessos.append((p[0].upper(), endereco_hex))
                except ValueError as e:
                    # Agora, se der erro, ele vai te avisar no console em vez de falhar em silêncio!
                    print(f"Aviso: Linha ignorada por erro de formatação -> {linha}")
                
        self.arquivo_carregado = caminho
        self.hr_lru_l2 = None 
        self.ciclos_lru = None
        if not caminho_silencioso:
            print(f"✅ Arquivo carregado com sucesso! ({len(self.acessos)} acessos lidos)")
        return True

    def testar_baseline(self, silencioso=False):
        if not self.acessos:
            if not silencioso: print("❌ Erro: Carregue um trace primeiro.")
            return
            
        if not silencioso: print("\n⏳ Executando Baseline (LRU)...")
        baseline = HierarquiaMemoria("LRU")
        for t, end in self.acessos:
            baseline.processar_acesso(t, end)
            
        hr_l1i = baseline.obter_hit_rate(baseline.l1i)
        hr_l1d = baseline.obter_hit_rate(baseline.l1d)
        self.hr_lru_l2 = baseline.obter_hit_rate(baseline.l2u)
        self.ciclos_lru = baseline.calcular_ciclos_totais()
        
        if not silencioso:
            print("\n" + "="*80)
            print(f"🏆 RESULTADO BASELINE (LRU)")
            print(f"-> L1 Instruções: {hr_l1i:.3f}%")
            print(f"-> L1 Dados:      {hr_l1d:.3f}%")
            print(f"-> L2 Unificada:  {self.hr_lru_l2:.3f}%")
            print(f"-> Ciclos Totais: {self.ciclos_lru:,} ciclos de hardware")
            print("="*80)

    def testar_aira_manual(self):
        if not self.acessos:
            print("❌ Erro: Carregue um arquivo de trace primeiro (Opção 1).")
            return
        if self.hr_lru_l2 is None:
            print("⚠️ Aviso: Você não rodou o Baseline. Calculando para fins de comparação...")
            self.testar_baseline(silencioso=True)
            
        print("\n--- Configurar Pesos Manuais (AIRA) ---")
        try:
            w_f = int(input("Digite o peso da Frequência (Ex: 4): "))
            w_i = int(input("Digite o peso da Idade (Ex: -1): "))
        except ValueError:
            print("❌ Erro: Valores inválidos. Digite apenas inteiros.")
            return

        print(f"\n⏳ Executando AIRA (Freq: {w_f}, Idade: {w_i})...")
        inicio = time.time()
        
        aira = HierarquiaMemoria("AIRA", w_f, w_i)
        for t, end in self.acessos:
            aira.processar_acesso(t, end)
            
        hr_l1i = aira.obter_hit_rate(aira.l1i)
        hr_l1d = aira.obter_hit_rate(aira.l1d)
        hr_l2 = aira.obter_hit_rate(aira.l2u)
        ciclos_aira = aira.calcular_ciclos_totais()
        
        print("\n" + "="*80)
        print(f"🎯 RESULTADO AIRA ({w_f}, {w_i}) - Tempo: {time.time() - inicio:.2f}s")
        print(f"-> L1 Instruções: {hr_l1i:.3f}%")
        print(f"-> L1 Dados:      {hr_l1d:.3f}%")
        print(f"-> L2 Unificada:  {hr_l2:.3f}%")
        print(f"-> Ciclos Totais: {ciclos_aira:,} ciclos de hardware")
        print("-" * 80)
        
        ganho_hr = hr_l2 - self.hr_lru_l2
        sinal_hr = "+" if ganho_hr > 0 else ""
        print(f"📈 GANHO HR L2: {sinal_hr}{ganho_hr:.3f}%")
        
        economia_ciclos = self.ciclos_lru - ciclos_aira
        ganho_tempo_pct = (economia_ciclos / self.ciclos_lru) * 100
        sinal_t = "+" if ganho_tempo_pct > 0 else ""
        print(f"⏱️ REDUÇÃO TEMPO: {sinal_t}{ganho_tempo_pct:.2f}% ({economia_ciclos:,} ciclos poupados)")
        print("="*80)

    def executar_grid_search(self):
        if not self.acessos:
            print("❌ Erro: Carregue um trace primeiro (Opção 1).")
            return
        if self.hr_lru_l2 is None:
            self.testar_baseline(silencioso=True)
            
        print("\n--- Grid Search Customizado ---")
        entrada_freq = input("Digite os pesos de Frequência separados por espaço (ex: 1 2 4 8): ")
        entrada_idade = input("Digite os pesos de Idade separados por espaço (ex: -1 -2 -4 -8): ")
        
        try:
            pesos_freq = [int(x) for x in entrada_freq.split()]
            pesos_idade = [int(x) for x in entrada_idade.split()]
        except ValueError:
            print("❌ Erro: Digite apenas números.")
            return

        print("\n⏳ Iniciando varredura... Isso pode levar algum tempo.")
        melhor_economia_abs = -float('inf')
        melhor_ganho = -float('inf')
        melhor_config = (0, 0)
        melhor_economia_pct = 0.0

        print("-" * 115)
        print(f"{'W_FREQ':<8} | {'W_IDADE':<8} | {'HR L1D':<8} | {'HR L2':<8} | {'GANHO HR':<10} | {'RED. CICLOS (%)':<17} | {'CICLOS TOTAIS'}")
        print("-" * 115)

        inicio = time.time()
        for w_f in pesos_freq:
            for w_i in pesos_idade:
                aira = HierarquiaMemoria("AIRA", w_f, w_i)
                for t, end in self.acessos:
                    aira.processar_acesso(t, end)
                    
                hr_l1d = aira.obter_hit_rate(aira.l1d)
                hr_l2 = aira.obter_hit_rate(aira.l2u)
                ciclos_aira = aira.calcular_ciclos_totais()
                
                ganho_hr = hr_l2 - self.hr_lru_l2
                economia_ciclos = self.ciclos_lru - ciclos_aira
                red_ciclos_pct = (economia_ciclos / self.ciclos_lru) * 100
                
                sinal_hr = "+" if ganho_hr > 0 else ""
                sinal_c = "+" if red_ciclos_pct > 0 else ""
                
                linha_tabela = (
                    f"{w_f:<8} | {w_i:<8} | {hr_l1d:>7.3f}% | {hr_l2:>7.3f}% | "
                    f"{sinal_hr}{ganho_hr:>8.3f}% | {sinal_c}{red_ciclos_pct:>6.2f}% ({economia_ciclos:>8,} c) | "
                    f"{ciclos_aira:,}"
                )
                print(linha_tabela)
                
                if economia_ciclos > melhor_economia_abs:
                    melhor_economia_abs = economia_ciclos
                    melhor_config = (w_f, w_i)
                    melhor_ganho = ganho_hr
                    melhor_economia_pct = red_ciclos_pct

        print("-" * 115)
        print(f"⏱️ Tempo total: {time.time() - inicio:.2f}s")
        print(f"🏆 Melhor Configuração: W_Freq = {melhor_config[0]}, W_Idade = {melhor_config[1]}")
        sinal_hr = "+" if melhor_ganho > 0 else ""
        sinal_c = "+" if melhor_economia_pct > 0 else ""
        print(f"🚀 Ganho L2: {sinal_hr}{melhor_ganho:.3f}% | Redução Ciclos: {sinal_c}{melhor_economia_pct:.2f}%")

    def executar_lote_automatico(self):
        print("\n" + "="*110)
        print("🚀 INICIANDO TESTE EM LOTE (Traces 1 a 5)")
        print("="*110)
        
        pesos_freq = [1, 2, 4, 8]
        pesos_idade = [-1, -2, -4, -8]
        
        for i in range(1, 8):
            arquivo = f"trace_{i}.txt"
            print(f"\n📁 Processando {arquivo}...")
            
            if not self.carregar_trace(arquivo):
                print(f"⚠️ Pulando {arquivo} (Não encontrado).")
                continue
                
            self.testar_baseline(silencioso=True)

            melhor_economia_abs = -float('inf')
            melhor_ganho = -float('inf')
            melhor_config = (0, 0)
            melhor_economia_pct = 0.0

            print("-" * 115)
            print(f"{'W_FREQ':<8} | {'W_IDADE':<8} | {'HR L1D':<8} | {'HR L2':<8} | {'GANHO HR':<10} | {'RED. CICLOS (%)':<17} | {'CICLOS TOTAIS'}")
            print("-" * 115)
            
            for w_f in pesos_freq:
                for w_i in pesos_idade:
                    aira = HierarquiaMemoria("AIRA", w_f, w_i)
                    for t, end in self.acessos:
                        aira.processar_acesso(t, end)
                        
                    hr_l1d = aira.obter_hit_rate(aira.l1d)
                    hr_l2 = aira.obter_hit_rate(aira.l2u)
                    ciclos_aira = aira.calcular_ciclos_totais()
                    
                    ganho_hr = hr_l2 - self.hr_lru_l2
                    economia_ciclos = self.ciclos_lru - ciclos_aira
                    red_ciclos_pct = (economia_ciclos / self.ciclos_lru) * 100
                    
                    sinal_hr = "+" if ganho_hr > 0 else ""
                    sinal_c = "+" if red_ciclos_pct > 0 else ""
                    
                    linha_tabela = (
                        f"{w_f:<8} | {w_i:<8} | {hr_l1d:>7.3f}% | {hr_l2:>7.3f}% | "
                        f"{sinal_hr}{ganho_hr:>8.3f}% | {sinal_c}{red_ciclos_pct:>6.2f}% ({economia_ciclos:>8,} c) | "
                        f"{ciclos_aira:,}"
                    )
                    print(linha_tabela)
                    
                    if economia_ciclos > melhor_economia_abs:
                        melhor_economia_abs = economia_ciclos
                        melhor_config = (w_f, w_i)
                        melhor_ganho = ganho_hr
                        melhor_economia_pct = red_ciclos_pct
            
            sinal_hr = "+" if melhor_ganho > 0 else ""
            sinal_c = "+" if melhor_economia_pct > 0 else ""
            print("-" * 115)
            print(f"🏆 Melhor no {arquivo}: Freq={melhor_config[0]}, Idade={melhor_config[1]}")
            print(f"   -> Ganho L2: {sinal_hr}{melhor_ganho:.3f}% | Redução Ciclos: {sinal_c}{melhor_economia_pct:.2f}%\n")
        
        print("✅ Lote finalizado!")

    def run(self):
        while True:
            print("\n" + "="*50)
            print("🧠 SIMULADOR DE CACHE MULTINÍVEL - PROJETO AIRA")
            print("="*50)
            status_arquivo = os.path.basename(self.arquivo_carregado) if self.arquivo_carregado else "Nenhum"
            print(f"Arquivo Atual: [{status_arquivo}]")
            print("-" * 50)
            print("1. Carregar Arquivo de Trace")
            print("2. Testar Cache Baseline (LRU)")
            print("3. Testar IA com Pesos Manuais")
            print("4. Executar Grid Search (Trace Atual)")
            print("5. Executar Lote Automático (Traces 1 a N)")
            print("0. Sair")
            print("="*50)
            
            opcao = input("Escolha uma opção: ").strip()
            
            if opcao == '1': self.carregar_trace()
            elif opcao == '2': self.testar_baseline()
            elif opcao == '3': self.testar_aira_manual()
            elif opcao == '4': self.executar_grid_search()
            elif opcao == '5': self.executar_lote_automatico()
            elif opcao == '0': break

if __name__ == "__main__":
    app = SimuladorApp()
    app.run()