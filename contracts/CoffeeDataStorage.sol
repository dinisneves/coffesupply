// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.30;

// Contrato: CoffeeDataStorage
// Guarda o estado dos lotes. Apenas o contrato CoffeeSupplyChain pode escrever aqui. 

contract CoffeeDataStorage {
 
    // Todos os estados possiveis que o lote pode possuir
    enum State {
        Harvested, // 0
        InTransit, // 1
        Delivered, // 2
        Processed, // 3
        Rejected,  // 4
        Certified  // 5
    }

    struct Batch {
        uint256 id;
        address creator;  // Quem criou o lote - Agricultor original
        address currentCustodian; // Quem tem a posse fisica atualmente do lote
        uint256 parentBatchId; // ID do lote anterior (usado para rastreabilidade)
        State state; // Estado atual do lote

        // Dados Imutáveis (Privavidade utilizando hash)
        string gpsCoordinates;
        string bioDataHash;

        //Dados dos sensores (para meios logisticos)
        uint256 tempMaxRegister;
        uint256 himidityRegister;

        // Certificação
        bool isCertified;
        string certDocHash; // Hash do certificado emitido
    }
    // Ter tambem mais informações do lote:
    // Peso do lote
    // Data de colheita
    // Data de entrega
    // Data de processamento
    // Data de rejeição
    // Data de certificação

    // ------------------------------- Funções de gestão -----------------------------
    mapping(uint256 => Batch) public batches; // Mapeamento de lotes por ID
    uint256 public batchCounter; 

    //Endereço do contrato CoffeeSupplyChain
    address public coffeeSupplyChainAddress; //supplyChainContract
    address public admin;

    modifier onlySupplyChain(){
        require(msg.sender == coffeeSupplyChainAddress, "Acesso negado: Apenas SupplyChain");
        _;
    }

    modifier onlyAdmin(){
        require(msg.sender == admin, "Acesso negado: Apenas Admin");
        _;
    }

    constructor(){
        admin = msg.sender;
    }


}