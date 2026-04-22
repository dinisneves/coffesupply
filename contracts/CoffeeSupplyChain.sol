// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.30;

// Import dos smartContracts para a comunicação entre eles
import "contracts/CoffeeAccessControl.sol";
import "contracts/CoffeeDataStorage.sol"; 

/**
 * @title CoffeeSupplyChain
 * @dev Contém a lógica de negócio e os gatilhos automáticos.
 */
contract CoffeeSupplyChain {
    // Variáveis que guardam onde estão os outros contratos 
    CoffeeAccessControl public accessContol;
    CoffeeDataStorage public dataStorage;

    // Regras de Negócio/Gatilhos para validar a qualidade do lote durante o transporte
    uint256 public constant MAX_TEMP_THRESHOLD = 30;
    uint256 public constant MAX_HUMIDITY_THRESHOLD = 65;

    // Eventos
    event Harvested(uint256 batchId, address indexed farmer);
    event TransportStarted(uint256 batchId, address indexed carrier);
    event TransportFinished(uint256 batchId, bool qualityPassed);
    event Processed(uint256 newBatchId, uint256 parentBatchId);
    event Certified(uint256 batchId, address indexed certifier);
    event TipSent(uint256 batchId, address indexed sender, address indexed farmer, uint256 amount);

    // Guarda os endereços dos contratos que já estão "publicados"
    constructor(address _accessControlAddr, address _dataStorageAddr){
        accessContol = CoffeeAccessControl(_accessControlAddr);
        dataStorage = CoffeeDataStorage(_dataStorageAddr);
    }

    // --- 1. AGRICULTOR: Colheita/Harvested ---
    function harvestBatch(string memory _gps, string memory _bioHash, string memory _variety) public {
        // Verificar se o endereço que está a chamar a função é um agricultor
        require(accessContol.hasRole(accessContol.FARMER_ROLE(), msg.sender), "Erro: Nao e Agricultor");
 
        // Chama o DataStorage para guardar os dados (Agora com os 4 argumentos!)
        uint256 newId = dataStorage.createBatch(msg.sender, _gps, _bioHash, _variety);

        emit Harvested(newId, msg.sender);
    }

     // --- 2.  TRANSPORTE - Ponto A - Inicio ---
    function startTransport(uint256 _batchId) public {
        // Verificar se o endereço que está a chamar a função é um transportador
        require(accessContol.hasRole(accessContol.CARRIER_ROLE(), msg.sender), "Erro: Nao e transportador");

        // Verificar estado
        CoffeeDataStorage.State currentState = dataStorage.getBatchState(_batchId);

        // Verifica o estado do lote:
        // Só pode ser transportado se estiver Colhido ou Processado
        require(
            currentState == CoffeeDataStorage.State.Harvested || 
            currentState == CoffeeDataStorage.State.Processed,
            "O lote nao esta pronto para transporte"
        );

        //Mudar custódia e estado do lote
        dataStorage.updateCustodian(_batchId, msg.sender); // Agora o motorista tem a custódia do lote
        dataStorage.updateState(_batchId, CoffeeDataStorage.State.InTransit);

        emit TransportStarted(_batchId, msg.sender);
    }

    // --- 3. TRANSPORTE - Ponto B - Final ---
    function finishTransport(uint256 _batchId, uint256 _tempReading, uint256 _humidReading) public {
        // Apenas quem tem a custódia atual do lote (o motorista), pode finalizar o transporte
        require(dataStorage.getBatchCustodian(_batchId) == msg.sender, "Erro: sem custodia do lote");
        require(dataStorage.getBatchState(_batchId) == CoffeeDataStorage.State.InTransit, "Erro: O lote nao esta em transito");

        // Registar os dados que são imutabeis
        dataStorage.setSensorData(_batchId, _tempReading, _humidReading);

        // Gatiho (if this then that)
        if(_tempReading > MAX_TEMP_THRESHOLD || _humidReading > MAX_HUMIDITY_THRESHOLD){
            // Fallback: Rejeitar o lote
            dataStorage.updateState(_batchId, CoffeeDataStorage.State.Rejected);
            emit TransportFinished(_batchId, false); // False = Falhou qualidade
        }else{
            // Sucesso
            dataStorage.updateState(_batchId, CoffeeDataStorage.State.Delivered);
            emit TransportFinished(_batchId, true); // True = Passou qualidade
        }
    }

    // --- 4. Porcessamento : Transformação ---
    function processBatch(uint256 _parentBatchId, string memory _roastingDataHash) public {
        // Verificar se o endereço que está a chamar a função é um "processador"
        require(accessContol.hasRole(accessContol.PROCESSOR_ROLE(), msg.sender), "Erro: Nao e Processador");

        // Verifica se o lote chegou e foi aprovado
        // Verifica se o lote pai está "Delivered"
        CoffeeDataStorage.State parentState = dataStorage.getBatchState(_parentBatchId);
        require(parentState == CoffeeDataStorage.State.Delivered, "Erro: O lote pai nao foi entregue ou foi rejeitado");
    
        // Cria novo lote tranformado (Link para rastreabilidade)
        uint256 newId = dataStorage.createProcessedBatch(msg.sender, _roastingDataHash, _parentBatchId);

        emit Processed(newId, _parentBatchId);
    }

    // --- 5. Certificador: Validação ---
    function certifyBatch(uint256 _batchId, bool _isValid, string memory _docHash, string memory _carbonFootprint, string memory _socialImpact) public {
        // Verificar se o endereço que está a chamar a função é um "certificador"
        require(accessContol.hasRole(accessContol.CERTIFIER_ROLE(), msg.sender), "Erro: Nao e Certificador");

        dataStorage.setCertification(_batchId, _isValid, _docHash, _carbonFootprint, _socialImpact);
        
        emit Certified(_batchId, msg.sender);
   }

    // --- 6. CONSUMIDOR FINAL: Gratificação Direta ---
    // Envia fundos diretamente para o criador original do lote (Agricultor)
    function tipFarmer(uint256 _batchId) public payable {
        require(msg.value > 0, "Tem de enviar algum valor");
        
        // 1. Vai buscar o endereço do agricultor usando o novo Getter
        address payable farmer = payable(dataStorage.getBatchCreator(_batchId));
        
        // 2. Transferência direta via Smart Contract
        (bool success, ) = farmer.call{value: msg.value}("");
        require(success, "Falha no envio da gratificacao");
        
        // 3. Emite o evento de sucesso
        emit TipSent(_batchId, msg.sender, farmer, msg.value);
    }
}
