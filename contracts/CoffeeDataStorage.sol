// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title CoffeeDataStorage
 * @dev Atua como a base de dados (Cofre) do sistema.
 * Padrão de Arquitetura: Data/Logic Separation. Este contrato apenas guarda o estado,
 * não contém lógica de negócio. Todos os sets são controlados pelo CoffeeSupplyChain.
 */
contract CoffeeDataStorage {

    // Estados do lote
    enum State { Harvested, InTransit, Delivered, Processed, RetailReady, Rejected, Certified }

    // --- ESTRUTURAS DE DADOS MODULARES ---
    // Sub-estruturas - "Passaporte Digital"

    // Bloco de Origem - registado pelo Agricultor
    struct OriginDetails {
        string propertyName;
        string farmerID;
        string gpsCoordinates;
        string speciesVariety;
        string plantingDate;
        string fertilizerDetails;
        string sustainablePractices;
    }

    // Dados de transporte, qualidade física e armazenamento
    struct LogisticsDetails {
        string carrierName;
        string vehicleID;
        string route;
        string storageType;
        string beanGrade;
        string processMethod;
        uint256 weight;
    }

    // Dados de transformação industrial
    struct ProductionDetails {
        string manufacturerName;
        string roastCurve;
        string energySource;
        string blendType;
        string isoCertification;
    }

    // Estrutura agregadora (O Passaporte Digital Completo)
    struct Batch {
        uint256 id;
        uint256 parentBatchId;    // Permite rastreabilidade retroativa caso o modelo escale
        address creator;          // Endereço original (usado para o Direct Tipping)
        address currentCustodian;  // Indica quem tem a custódia
        State state;

        OriginDetails origin;
        LogisticsDetails logistics;
        ProductionDetails production;

        uint256 tempMax;          // Dados de sensores IoT inseridos pós-transporte
        uint256 humMax;

        string carbonFootprint;   // Emissão de CO2 (kg) por lote
        string socialImpact;      // Impacto social calculado
        bool isCertified;         // Indica se o lote está certificado
        string certDocHash;       // Hash IPFS do certificado (Privacidade On-Chain/Off-Chain)
        string scaScore;          // Pontuação SCA (Specialty Coffee Association)
    }

    // --- ARMAZENAMENTO E VARIÁVEIS DE ESTADO ---
    // Tem de ser private para evitar o erro "Stack too deep" devido aos limites de memória da EVM.
    mapping(uint256 => Batch) private batches;

    uint256 public batchCounter;

    // Controlo de Acesso Interno
    address public supplyChainAddress; // Endereço do contrato de Lógica (Cérebro)
    address public admin;

    // --- MODIFIERS (Segurança) ---
    // Garante que o estado apenas pode ser alterado através das regras de negócio do contrato principal
    modifier onlySupplyChain() {
        require(msg.sender == supplyChainAddress, "Acesso negado: Apenas SupplyChain");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Acesso negado: Apenas Admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // Injeção de dependência: Liga o Cofre ao Cérebro após o deploy de ambos
    function setSupplyChainAddress(address _addr) external onlyAdmin {
        supplyChainAddress = _addr;
    }

    // --- FUNÇÕES DE ESCRITA (SETTERS) ---

    function createBatch(address _creator, OriginDetails memory _origin) external onlySupplyChain returns (uint256) {
        batchCounter++;
        uint256 id = batchCounter;

        batches[id].id = id;
        batches[id].creator = _creator;
        batches[id].currentCustodian = _creator; // Na colheita, o criador é o primeiro detentor
        batches[id].state = State.Harvested;
        batches[id].origin = _origin;

        return id;
    }

    function updateLogistics(uint256 _id, LogisticsDetails memory _log) external onlySupplyChain {
        batches[_id].logistics = _log;
    }

    function updateProduction(uint256 _id, ProductionDetails memory _prod) external onlySupplyChain {
        batches[_id].production = _prod;
        batches[_id].state = State.Processed; // Transição automática de estado após torrefação
    }

    function setCertification(
        uint256 _id,
        bool _status,
        string memory _hash,
        string memory _carbon,
        string memory _social,
        string memory _sca
    ) external onlySupplyChain {
        batches[_id].isCertified = _status;
        batches[_id].certDocHash = _hash;
        batches[_id].carbonFootprint = _carbon;
        batches[_id].socialImpact = _social;
        batches[_id].scaScore = _sca;

        if (_status) batches[_id].state = State.Certified;
    }

    function updateState(uint256 _id, State _newState) external onlySupplyChain {
        batches[_id].state = _newState;
    }

    function updateCustodian(uint256 _id, address _cust) external onlySupplyChain {
        batches[_id].currentCustodian = _cust;
    }

    function setSensorData(uint256 _id, uint256 _t, uint256 _h) external onlySupplyChain {
        batches[_id].tempMax = _t;
        batches[_id].humMax = _h;
    }

    // --- FUNÇÕES DE LEITURA MODULARES (GETTERS) ---

    function getBatchOrigin(uint256 _id) external view returns (OriginDetails memory) {
        return batches[_id].origin;
    }

    function getBatchLogistics(uint256 _id) external view returns (LogisticsDetails memory) {
        return batches[_id].logistics;
    }

    function getBatchProduction(uint256 _id) external view returns (ProductionDetails memory) {
        return batches[_id].production;
    }

    // Retorna os metadados fundamentais e leituras de IoT
    function getBatchCore(uint256 _id) external view returns (
        uint256 parentId,
        address creator,
        address custodian,
        State state,
        uint256 tempMax,
        uint256 humMax
    ) {
        Batch storage b = batches[_id];
        return (b.parentBatchId, b.creator, b.currentCustodian, b.state, b.tempMax, b.humMax);
    }

    // Retorna os dados do Oráculo/Auditoria
    function getBatchCertifications(uint256 _id) external view returns (
        bool isCertified,
        string memory certDocHash,
        string memory carbonFootprint,
        string memory socialImpact,
        string memory scaScore
    ) {
        Batch storage b = batches[_id];
        return (b.isCertified, b.certDocHash, b.carbonFootprint, b.socialImpact, b.scaScore);
    }

    // Getters auxiliares utilizados pelo contrato de Lógica para validações de RBAC e Geração de Eventos
    function getBatchState(uint256 _id) external view returns (State) {
        return batches[_id].state;
    }

    function getBatchCustodian(uint256 _id) external view returns (address) {
        return batches[_id].currentCustodian;
    }

    function getBatchCreator(uint256 _id) external view returns (address) {
        return batches[_id].creator;
    }
}