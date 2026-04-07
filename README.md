# Caches Inteligentes em RISC-V (AIRA - Linear Regression)

## 📌 Sobre o Projeto
Este repositório contém o desenvolvimento do projeto da disciplina de **Projeto Integrador IV (2026/1)** da **Universidade Federal do Pampa (UNIPAMPA)**, ministrada pelo Prof. Bruno S. Neves. 

O objetivo do trabalho é projetar, implementar e avaliar um algoritmo inteligente para substituição de blocos em cache (AIRA - *AI based Replacement Algorithm*), focado em superar a política padrão LRU (*Least Recently Used*). O algoritmo escolhido para esta implementação é a **Regressão Linear**.

O projeto visa um processador RISC-V (RV32I) operando em ambiente *bare-metal* e será sintetizado para um FPGA Cyclone III (EP3C25F324C6), exigindo um rigoroso controle de área (LEs) e temporização ($F_{max}$).

## 👥 Equipe
* João Oliveira Duarte
* Lorhan Santos de Lima
* Raul Etcheverry Reis

## 📂 Estrutura do Repositório
A organização das pastas segue o padrão exigido na especificação do projeto:

* `/docs`: Relatório final (PDF), diagramas arquiteturais e apresentações.
* `/rtl`: Códigos-fonte em HDL (Verilog) para a cache e o core RISC-V.
* `/sim`: Testbenches e scripts de simulação (ModelSim).
* `/software`: Código-fonte dos benchmarks em C/Assembly utilizados para testes de estresse.
* `/synth`: Relatórios de síntese (utilização de área e timing do Quartus).

## 🚀 Status Atual
* **Sprint 0:** Setup do ambiente, equipe e ferramentas (Concluído).
* **Sprint 1:** Modelagem do algoritmo em Python/C e validação teórica do Hit Rate lógico (Em andamento).

---
*Projeto acadêmico - UNIPAMPA Campus Bagé*