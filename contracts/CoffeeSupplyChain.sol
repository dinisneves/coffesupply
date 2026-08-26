// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./CoffeeAccessControl.sol";
import "./CoffeeDataStorage.sol";

/**
 * @title CoffeeSupplyChain
 * @dev Contrato de Lógica de Negócio (Controller).
 * Padrão Arquitetural: Separação de Dados e Lógica. Este contrato orquestra as
 * transições de estado, valida as permissões (RBAC) e executa os "Smart Triggers",
 * serve como a única interface para escrever no CoffeeDataStorage.
 */
contract CoffeeSupplyChain {

    // --- DEPENDÊNCIAS DE SISTEMA ---
    // Injeção de dependências dos módulos de Controlo de Acesso e Base de Dados.
    CoffeeAccessControl public access;
    CoffeeDataStorage public dataStorage;

    // --- REGRAS DE NEGÓCIO IMUTÁVEIS ---
    // Limites operacionais para os smart triggers de IoT.
    uint256 public constant MAX_TEMP = 30;
    uint256 public constant MAX_HUM = 65;

    // --- EVENTOS DE INTEGRAÇÃO ---
    event Harvested(uint256 indexed batchId, address indexed farmer);
    event TransportStarted(uint256 indexed batchId, address indexed carrier);
    event TransportFinished(uint256 indexed batchId, bool qualityPassed);
    event Processed(uint256 indexed batchId, address indexed processor);
    event RetailReady(uint256 indexed batchId, address indexed retailer);
    event Certified(uint256 indexed batchId, address indexed certifier);
    event TipSent(uint256 indexed batchId, address indexed sender, address indexed farmer, uint256 amount);

    // Construtor: Inicializa as referências aos contratos auxiliares no momento do deploy.
    constructor(address _access, address _storage) {
        access = CoffeeAccessControl(_access);
        dataStorage = CoffeeDataStorage(_storage);
    }

    // =========================================================================
    // --- FLUXOS DE NEGÓCIO DA SUPPLY CHAIN ---
    // =========================================================================

    // --- 1. Criação do lote ---
    function harvestBatch(CoffeeDataStorage.OriginDetails memory _origin) public {
        // Validação RBAC: Previne a injeção de dados falsos por contas não autorizadas.
        require(access.hasRole(access.FARMER_ROLE(), msg.sender), "Acesso negado: Requer privilegios de Agricultor");

        uint256 newId = dataStorage.createBatch(msg.sender, _origin);

        emit Harvested(newId, msg.sender);
    }

    // --- 2. Início do Transporte ---
    function startTransport(uint256 _id) public {
        require(access.hasRole(access.CARRIER_ROLE(), msg.sender), "Acesso negado: Requer privilegios de Transportador");

        // Validação de Estado: Previne que um lote seja transportado antes de ser processado ou colhido.
        CoffeeDataStorage.State currentState = dataStorage.getBatchState(_id);
        require(
            currentState == CoffeeDataStorage.State.Harvested ||
            currentState == CoffeeDataStorage.State.Processed,
            "Erro de Integridade: Estado atual do lote nao permite movimentacao logistica"
        );

        // Transfere a responsabilidade do lote para o transportador.
        dataStorage.updateCustodian(_id, msg.sender);
        dataStorage.updateState(_id, CoffeeDataStorage.State.InTransit);

        emit TransportStarted(_id, msg.sender);
    }

    // --- 3. Entrega do lote ---
    function finishTransport(
        uint256 _id,
        uint256 _t,
        uint256 _h,
        CoffeeDataStorage.LogisticsDetails memory _log
    ) public {
        // Validação de Segurança: Garante que apenas o transportador atual possa finalizar o transporte.
        require(dataStorage.getBatchCustodian(_id) == msg.sender, "Erro de Seguranca: Remetente nao possui a custodia deste lote");
        require(dataStorage.getBatchState(_id) == CoffeeDataStorage.State.InTransit, "Erro de Sequencia: Lote nao se encontra em transito");

        dataStorage.setSensorData(_id, _t, _h);
        dataStorage.updateLogistics(_id, _log);

        // SMART TRIGGER:
        if (_t > MAX_TEMP || _h > MAX_HUM) {
            dataStorage.updateState(_id, CoffeeDataStorage.State.Rejected);
            emit TransportFinished(_id, false);
        } else {
            dataStorage.updateState(_id, CoffeeDataStorage.State.Delivered);
            emit TransportFinished(_id, true);
        }
    }

    // --- 4. Processamento ---
    function processProduction(uint256 _id, CoffeeDataStorage.ProductionDetails memory _prod) public {
        require(access.hasRole(access.PROCESSOR_ROLE(), msg.sender), "Acesso negado: Requer privilegios de Processador");
        require(dataStorage.getBatchState(_id) == CoffeeDataStorage.State.Delivered, "Restricao de Qualidade: Lote nao validado para processamento");

        dataStorage.updateProduction(_id, _prod);

        emit Processed(_id, msg.sender);
    }

    // --- 5. Certificação do lote ---
    function certifyBatch(
        uint256 _id,
        bool _val,
        string memory _hash,
        string memory _carbon,
        string memory _social,
        string memory _sca
    ) public {
        require(access.hasRole(access.CERTIFIER_ROLE(), msg.sender), "Acesso negado: Requer privilegios de Auditor/Oraculo externo");

        // Previne a certificação de lotes rejeitados por falhas de IoT ou lotes incompletos.
        CoffeeDataStorage.State currentState = dataStorage.getBatchState(_id);
        require(currentState != CoffeeDataStorage.State.Rejected, "Erro de Integridade: Nao e possivel certificar um lote rejeitado");
        require(
            currentState == CoffeeDataStorage.State.Processed || currentState == CoffeeDataStorage.State.RetailReady,
            "Erro de Sequencia: Lote deve estar processado para receber certificacao final"
        );

        dataStorage.setCertification(_id, _val, _hash, _carbon, _social, _sca);

        emit Certified(_id, msg.sender);
    }

    // --- 6. Passar o lote para venda ---
    function markAsRetailReady(uint256 _id) public {
        require(access.hasRole(access.RETAILER_ROLE(), msg.sender), "Acesso negado: Requer privilegios de Retalho");

        // VALIDAÇÃO DE ESTADO: Garante que o lote passou obrigatoriamente pela fase de certificação
        CoffeeDataStorage.State currentState = dataStorage.getBatchState(_id);
        require(currentState == CoffeeDataStorage.State.Certified, "Erro de Integridade: O lote deve estar certificado antes de ser colocado a venda");

        dataStorage.updateCustodian(_id, msg.sender);
        dataStorage.updateState(_id, CoffeeDataStorage.State.RetailReady);

        emit RetailReady(_id, msg.sender);
    }

    // --- 7. Gorjeta para o agricultor ---
    function tipFarmer(uint256 _id) public payable {
        // Garante que o lote está pronto para o consumidor
        CoffeeDataStorage.State currentState = dataStorage.getBatchState(_id);
        require(currentState == CoffeeDataStorage.State.RetailReady, "Erro: Apenas pode dar gorjeta a produtos que chegaram ao mercado com sucesso.");

        // Exige que a transação possua valor nativo (ETH/Wei) anexado.
        require(msg.value > 0, "Transacao Rejeitada: Necessario anexar valor monetario");

        address payable farmer = payable(dataStorage.getBatchCreator(_id));

        (bool success, ) = farmer.call{value: msg.value}("");
        require(success, "Falha na execucao EVM: Transferencia P2P revertida");

        emit TipSent(_id, msg.sender, farmer, msg.value);
    }
}