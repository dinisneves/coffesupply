
# 📦 Fluxo de Execução dos Smart Contracts – Supply Chain do Café

## 🔧 Requisitos
- 5 contas Ethereum diferentes (usar as contas do Remix)
- Contratos:
  - CoffeeAccessControl
  - CoffeeDataStorage
  - CoffeeSupplyChain

## 🟢 Fase 0: Configuração Inicial
**Quem executa:** Admin (1ª conta)

### Deploy
- Deploy dos contratos:
  - CoffeeAccessControl
  - CoffeeDataStorage
  - CoffeeSupplyChain

### Ligação Storage ↔ Lógica
Contrato: CoffeeDataStorage  
Função: setSupplyChainAddress  
Input: Endereço do contrato CoffeeSupplyChain

## 🟡 Fase 1: Configuração dos Stakeholders
**Quem executa:** Admin

- Agricultor → grantRole(FARMER_ROLE, 2ª conta)
- Transportador → grantRole(CARRIER_ROLE, 3ª conta)
- Processador → grantRole(PROCESSOR_ROLE, 4ª conta)
- Certificador → grantRole(CERTIFIER_ROLE, 5ª conta)

## 🌱 Fase 2: Origem / Colheita
**Quem executa:** Agricultor (2ª conta)

Função: harvestBatch  
Input:
- GPS: "111.11, -111.111"
- bioHash

Resultado:
- Lote criado com id = 1
- Estado: Harvested

## 🚚 Fase 3: Início do Transporte
**Quem executa:** Transportador (3ª conta)

Função: startTransport
Input:
- id do lote: 1
  
Resultado:
- Estado: InTransit
- Novo dono: Transportador
- Caso seja outra conta a tentar usar o startTransport, irá dar erro.

## 📡 Fase 4: Fim do Transporte
**Quem executa:** Transportador

Função: finishTransport
Input:
- id do lote: 1
- Temperatura: 22
- Humidade: 50
  
Resultado:
- Delivered se temperatura ≤ 30 e humidade ≤ 65
- Rejected caso contrário

## 🏭 Fase 5: Processamento
**Quem executa:** Processador (4ª conta)

Função: processBatch
Input:
- id do lote: 1
- roastingDataHash: "hash da torra"
  
Resultado:
- Novo lote id = 2
- Estado: Processed

## 🏷️ Fase 6: Certificação
**Quem executa:** Certificador (5ª conta)

Função: certifyBatch
Input:
- id do lote original: 1
- isValid: true
- docHash: "Hash do cerificado oficial"

  
Resultado:
- Lote 1 certificado
- Lote 2 herda do lote 1, existindo uma herança 

## 🔄 Resumo do Fluxo
Admin → Setup  
Agricultor → harvestBatch  
Transportador → startTransport / finishTransport  
Processador → processBatch  
Certificador → certifyBatch
