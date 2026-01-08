// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.30;

// Contrato: CoffeAccessControl
// Gere as permissões de todos os intervenientes do sistema

contract CoffeAccessControl {
    // keccak256 é usado para geriar um ID único e seguro para cada role
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant FARMER_ROLE = keccak256("FARMER");
    bytes32 public constant CARRIER_ROLE = keccak256("CARRIER");
    bytes32 public constant PROCESSOR_ROLE = keccak256("PROCESSOR");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER");
    bytes32 public constant CERTIFIER_ROLE = keccak256("CERTIFIER");

    // Guardar permissões
    // Mapeia: role -> (wallet address -> Verdadeiro/Falso)
    mapping(bytes32 => mapping(address => bool)) private _roles;

    // Mensagem para os eventos
    bytes32 public constant MSG_ROLE_GRANTED      = keccak256("ROLE_GRANTED");
    bytes32 public constant MSG_ROLE_REVOKED      = keccak256("ROLE_REVOKED");
    bytes32 public constant MSG_ALREADY_HAS_ROLE  = keccak256("ALREADY_HAS_ROLE");
    bytes32 public constant MSG_ROLE_NOT_ASSIGNED = keccak256("ROLE_NOT_ASSIGNED");


    // Eventos - É como se fosse um "print" na consola
    event RoleGranted(bytes32 indexed role, address indexed account, bytes32 reason);
    event RoleRevoked(bytes32 indexed role, address indexed account, bytes32 reason);

    constructor(){
        // A pessoa que fizer deploy do contrato é automáticamente atribuido a role do admin
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // Modificadores - Gatilho
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Acesso negado: Apenas Admin pode aceder");
        _;
    }


    // ------------------------------- Funções de gestão -----------------------------

    // Função para verificar se a pessoa tem permissões
    function hasRole(bytes32 role, address account) public view returns (bool){
        return _roles[role][account];
    }

    //Função de atribuir role - apenas pode ser usada pelo admin
    function grantRole(bytes32 role, address account) public onlyAdmin {
        _grantRole(role, account);
    }

    // Função para atribuir uma role a uma wallet/conta
    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role][account]){ // Verifica se a wallet/conta não tem a role indicada
            _roles[role][account] = true;
            emit RoleGranted(role, account, MSG_ROLE_GRANTED); // Envia um evento a informar que a wallet/conta passa a ter a role indicada
        } else{
            emit RoleGranted(role, account, MSG_ALREADY_HAS_ROLE); // Envia um evento a informar que a wallet/conta já possui a role indicada
        }
    }

    // Função para remover a role a uma wallet/conta
    function revokeRole(bytes32 role, address account) public onlyAdmin {
        if (_roles[role][account]){ // Verifica se a wallet/conta tem a role indicada
            _roles[role][account] = false; 
            emit RoleRevoked(role, account, MSG_ROLE_REVOKED); // Envia um evento a informar que a wallet/conta com a role indicada passa a estar indisponível
        } else { // Envia um evento a informar que a wallet/conta não tem a role indicada
            emit RoleRevoked(role, account, MSG_ROLE_NOT_ASSIGNED);
        }
    }
}