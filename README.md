Fluxo da execução dos smart contracts.

Requisitos: - 5 contas diferentes (usar as contas do remix)

Guião: Fase 0: Configuração Inicial - Quem executa é o admin, ou seja, a 1º conta 1. Deploy; Fazer o deploy dos 3 contratos (AccessControl, DataStorage, SupplyChain) 2. Ligar o Storage à lógica: - Vai ao contracto CoffeDataStorage - Na função setSupplyChainAddress - No input [Endereço do contrato SupplyChain] - Transact - Basicamente isto é necessário para dar permissões de escrita ao contrato princiapl

Fase 1: Configurar Stackeholders
    - Quem executa é a conta Admin, ou seja, a 1º conta no contrato CoffeeAccessControl
    - Associar roles às contas
    1. Criar Agricultor
        - Usa a função grantRole
        - Input - Has do FARMER_ROLE e Endereço da 2º conta
    2. Criar Transportador
        - Usando a função grantRole
        - Input - Has do CARRIER_ROLE e Endereço da 3º conta
    3. Criar Processador
        - Usa a função grantRole
        - Input - Has do PROCESSOR_ROLE e Endereço da 4º conta
    4. Criar Certificador
        - Usando a função grantRole
        - Input - Has do CERTIFIER_ROLE e Endereço da 5º conta
Fase 2: Configurar o Lote - Origem/Colheita
    - Quem executa é a conta do Agricultor, ou seja, a 2º conta no contrato CoffeSupplyChain
    1. Ações:
        - Usa a função harvestBatch
        - Input - coordenadas do gps ("111.11, -111.111") e bioHash ("Hasd do pdf...")
    2. Resultado:
        - O sistema cria o lote com o id 1 no estado Harvested
Fase 3: Logistica - Inicio do Transporte 
    - Quem executa é a conta do transportador, ou seja, a 3º conta no contrato CoffeSupplyChain
    1. Ações:
        - Usa a função startTransport
        - Input - id do lote, no caso seria o 1
    2. Resultado:
        - O lote com o id 1 muda de dono, passando a pertencer à conta 3 com o estado de "InTransit"
        - Caso seja outra conta a tentar usar o startTransport, irá dar erro.
Fase 4: Logistica - Fim do transporte e entrega dos dados IoT (sensores)
    - Quem executa é a conta do transportador, ou seja, a 3º conta no contrato CoffeSupplyChain
    1. Ações:
        - Usa a função finishTransport
        - Input - id do lote, temperatura registada, e humidade
    2. Resultado:
        - São validados os valores dos sensores e se estiverem bons o estado passa para "Delivered"
        - Se a temperatura for acima dos 30 ou a humidade acima dos 65, o estado passa para "Rejected" e o fluxo para aqui.
Fase 5: Processamento Industrial
    - Quem executa é a conta do processador, ou seja, a 4º conta no contrato CoffeSupplyChain
    1. Ações:
        - Usa a função processBatch
        - Input - Id do batch orginal, 1 + roastingDataHash ("has da torra").
    2. Resultado
        - Agora passa a existir um novo lote, sendo este um lote processado com o id 2
        - O novo lote passa a ter o estado "Processed"
Fase 6: Certificação - Selo de Confiança
    - Quem executa é a conta do certificador, ou seja, a 5º conta no contrato CoffeSupplyChain
    1. Ações:
        - Usa a função certifyBatch
        - Input - id do batch original (1) + true (se é valido ou não) + docHash ("Hash do Certificado Oficial")
    2. Resultado:
        - O lote 1 passa a ser marcado como "isCertified = true". 
        - Quem consultar o lote 2 (o produto final) e seguir o rasto até ao lote 1, verá que a origem é certificada.

Resumo Visual do Fluxo:
    1. Admin: Setup Inicial
    2. Agricultor: harvestBatch (Cria o lote com id 1)
    3. Transportador: startTransport(1)
    4. Transportador: finishTransport(1, 22, 50)
    5. Processador: processBatch(1) - Cria um novo lote com o id 2
    6. Certificador: certifyBatch(1)
