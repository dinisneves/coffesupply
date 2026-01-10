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
    event Transport(uint256 batchId, address indexed carrier);
    event TransportStarted(uint256 batchId, bool qualityPassed);
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

}