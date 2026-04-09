// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.30;

// @title CoffeeDataStorage
// @dev Guarda o estado dos lotes. Apenas o contrato CoffeeSupplyChain pode escrever aqui. 

contract CoffeeDataStorage {
 
    // --- MODELAGEM DE DADOS ---
    // Todos os estados possiveis que o lote pode possuir
    enum State {
        Harvested, // 0
        InTransit, // 1
        Delivered, // 2
        Processed, // 3
        Rejected,  // 4
        Certified  // 5
    }

    // A estrutura do lote
    struct Batch {
        uint256 id;                 // Identificador único
        address creator;            // Endereço de quem criou o lote - Agricultor original
        address currentCustodian;   // Endereço de quem tem a posse fisica atualmente do lote
        uint256 parentBatchId;      // ID do lote anterior (usado para rastreabilidade)
        State state;                // Estado atual do lote

        // Dados Imutáveis (Privavidade utilizando hash)
        string gpsCoordinates;
        string bioDataHash;

        string coffeeVariety; // Ex: "Arábica Typica" [cite: 292]
        string carbonFootprint;   // Ex: "2.4kg CO2/kg"
        string socialImpact;      // Ex: "Apoio a 10 famílias locais"


        //Dados dos sensores - IoT (para meios logisticos)
        uint256 tempMaxRegister;    // Temperatura máxima registada
        uint256 humidityRegister;   // Humidade registada

        // Certificação
        bool isCertified;           // Se o lote está certificado
        string certDocHash;         // Hash do certificado emitido
    }
    // Ter tambem mais informações do lote:
    // Peso do lote
    // Data de colheita
    // Data de entrega
    // Data de processamento
    // Data de rejeição
    // Data de certificação

    // ------------------------------- Funções de gestão -----------------------------
    mapping(uint256 => Batch) public batches; // Mapeamento de lotes por ID, tipo (1,2,3)
    uint256 public batchCounter;              // Contador que serve para auto incrementar o id do Batch

    //Endereço do contrato CoffeeSupplyChain
    address public coffeeSupplyChainAddress; //SupplyChainContract
    address public admin;


    // Garante que só o contrato CoffeeSupplyChain pode alterar dados neste contrato (CoffeeDataStorage)
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


    // Configuração: Ligação ao contrato CoffeeSupplyChain
    // Basicamente dizemos "Apenas obedece às ordens do enderexo X"
    function setCoffeeSupplyChainAddress(address _coffeeSupplyChainAddress) external onlyAdmin{
        coffeeSupplyChainAddress = _coffeeSupplyChainAddress;
    }

    // --- SETTERS (Funções chamadas pelo contrato CoffeeSupplyChain) ---

    // Função para criar o lote
    function createBatch(address _creator, string memory _gps, string memory _bioHash, string memory _variety) external onlySupplyChain returns (uint256) {
        batchCounter++;  // Incrementa o ID
        uint256 newId = batchCounter;

        // Preenche os dados iniciais para criar um novo lote
        batches[newId].id = newId; // Id do lote
        batches[newId].creator = _creator; // Endereço do agricultor
        batches[newId].currentCustodian = _creator; // Endereço do agricultor (Porque no inicio é a mesma pessoa que o criador do lote)
        batches[newId].state = State.Harvested; // Estado do lote (Colhido)
        batches[newId].gpsCoordinates = _gps; // Coordenadas do local onde foi colhido 
        batches[newId].bioDataHash = _bioHash; 
        batches[newId].coffeeVariety = _variety; // Guarda a variedade [cite: 292]

        return newId;   // Devolve o ID para o contrato CoffeeSupplyChain emitir o evento
    }


    // Cria um lote "transformado", pois esta já vai depender de um lote existente
    function createProcessedBatch(address _processor, string memory _dataHash, uint256 _parentId) external onlySupplyChain returns (uint256) {
        batchCounter++;
        uint256 newId = batchCounter;

        batches[newId].id = newId;
        batches[newId].creator = _processor;
        batches[newId].currentCustodian = _processor;
        batches[newId].parentBatchId = _parentId; // Link para rastreabilidade para o lote anterior, criando o elo entre lotes
        batches[newId].state = State.Processed;
        batches[newId].bioDataHash = _dataHash; // Reutilizando campo para dados de processamento

        return newId;
    }

    // Alterar o estado do lote
    function updateState(uint256 _id, State _newState) external onlySupplyChain {
        batches[_id].state = _newState;
    }

    // Alterar o "dono" do lote, ou seja, quem possui a custódia do lote
    function updateCustodian(uint256 _id, address _newCustodian) external onlySupplyChain {
        batches[_id].currentCustodian = _newCustodian;
    }

    // Registar os dados dos sensores durante o transporte do lote
    function setSensorData(uint256 _id, uint256 _temp, uint256 _hum) external onlySupplyChain {
        batches[_id].tempMaxRegister = _temp;
        batches[_id].humidityRegister = _hum;
    }

    // Associar ceriticados ao lote
    function setCertification(uint256 _id, bool _status, string memory _docHash) external onlySupplyChain {
        batches[_id].isCertified = _status;
        batches[_id].certDocHash = _docHash;
        if(_status) {
            batches[_id].state = State.Certified;
        }
    }

    // --- GETTERS ---

    // Função para obter o estado do lote
    function getBatchState(uint256 _id) external view returns (State) {
        return batches[_id].state;
    }

    // Função para obter quem está com a custódia do lote
    function getBatchCustodian(uint256 _id) external view returns (address) {
        return batches[_id].currentCustodian;
    }

    // Função para obter o criador original do lote (Agricultor)
    function getBatchCreator(uint256 _id) external view returns (address) {
        return batches[_id].creator;
    }

    // Função de Leitura Completa para o Consumidor
    function getBatchFullInfo(uint256 _id) public view returns (string memory origem, string memory variedade, string memory certificacao, string memory pegadaCarbono, string memory impactoSocial, State estadoAtual){
        Batch storage b = batches[_id];
        return (b.gpsCoordinates, b.coffeeVariety, b.certDocHash, b.carbonFootprint,   b.socialImpact, b.state);
    }
}