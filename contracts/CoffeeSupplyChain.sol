// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.30;

import "contracts/CoffeeAccessControl.sol";
import "contracts/CoffeeDataStorage.sol"; 

/**
 * @title CoffeeSupplyChain
 * @dev Contém a lógica de negócio e os gatilhos automáticos.
 */
contract CoffeeSupplyChain {
    CoffeeAccessControl public accessContol;
    CoffeeDataStorage public dataStorage;

    // Regras/Gatilhos para validar a qualidade
    uint256 public constant MAX_TEMP_THRESHOLD = 30;
    uint256 public constant MAX_HUMIDITY_THRESHOLD = 65;

    // Eventos
    event Harvested(uint256 batchId, address indexed farmer);
    event TransportStarted(uint256 batchId, address indexed carrier);
    event TransportFinished(uint256 batchId, bool qualityPassed);
    event Processed(uint256 newBatchId, uint256 parentBatchId);
    event Certified(uint256 batchId, address indexed certifier);

    constructor(address _accessControlAddr, address _dataStorageAddr){
        accessContol = CoffeeAccessControl(_accessControlAddr);
        dataStorage = CoffeeDataStorage(_dataStorageAddr);
    }

    // --- 1. AGRICULTOR: Colheita/Harvested ---
    function harvestBatch(string memory _gps, string memory _bioHash) public {
        require(accessContol.hasRole(accessContol.FARMER_ROLE(), msg.sender), "Erro: Nao e Agricultor");
        uint256 newId = dataStorage.createBatch(msg.sender, _gps, _bioHash);
        emit Harvested(newId, msg.sender);
    }

     // --- 2.  TRANSPORTE - Ponto A - Inicio ---
    function startTransport(uint256 _batchId) public {
        require(accessContol.hasRole(accessContol.CARRIER_ROLE(), msg.sender), "Erro: Nao e transportador");

        // Verificar estado
        CoffeeDataStorage.State currentState = dataStorage.getBatchState(_batchId);
        require(
            currentState == CoffeeDataStorage.State.Harvested || 
            currentState == CoffeeDataStorage.State.Processed,
            "Lote nao pronto para transporte"
        );

        //Mudar custódia e estado do lote
        dataStorage.updateCustodian(_batchId, msg.sender);
        dataStorage.updateState(_batchId, CoffeeDataStorage.State.InTransit);

        emit TransportStarted(_batchId, msg.sender);
    }

    // --- 3. TRANSPORTE - Ponto B - Final ---
    function finishTransport(uint256 _batchId, uint256 _tempReading, uint256 _humidReading) public {
        // Apenas quem tem a custódia atual do lote (o motorista), pode finalizar o transporte
        require(dataStorage.getBatchCustodian(_batchId) == msg.sender, "Erro: sem custodia do lote");
        require(dataStorage.getBatchState(_batchId) == CoffeeDataStorage.State.InTransit, "Erro: Lote nao esta em transito");

        // Registar os dados que são imutabeis
        dataStorage.setSensorData(_batchId, _tempReading, _humidReading);

        // Gatiho 
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

    // --- 4. PROCESADOR: Transformação ---
    function processBatch(uint256 _parentBatchId, string memory _roastingDataHash) public {
        require(accessContol.hasRole(accessContol.PROCESSOR_ROLE(), msg.sender), "Erro: Nao e Processador");

        // Verifica se o lote chegou e foi aprovado
        CoffeeDataStorage.State parentState = dataStorage.getBatchState(_parentBatchId);
        require(parentState == CoffeeDataStorage.State.Delivered, "Erro: Lote pai nao entregue ou rejeitado");
    
        // Cria novo lote derivado (Link para rastreabilidade)
        uint256 newId = dataStorage.createProcessedBatch(msg.sender, _roastingDataHash, _parentBatchId);


        emit Processed(newId, _parentBatchId);
    }

    // --- 5. Certificador: Validação ---
    function certifyBatch(uint256 _batchId, bool _isValid, string memory _docHash) public {
        require(accessContol.hasRole(accessContol.CERTIFIER_ROLE(), msg.sender), "Erro: Nao e Certificador");

        dataStorage.setCertification(_batchId, _isValid, _docHash);
        
        emit Certified(_batchId, msg.sender);
   }
}