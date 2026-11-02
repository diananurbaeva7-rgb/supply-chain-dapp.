// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SupplyChain — отслеживание партии товара по цепочке поставок
/// @notice Учебный проект: производитель -> перевозчик -> склад -> магазин
contract SupplyChain {
    enum Status { Produced, InTransit, Delivered }

    struct Product {
        uint256 id;
        string name;
        string metadataCID; // CID документов (накладная, сертификат) в IPFS
        address owner;
        Status status;
        bool exists;
    }

    struct HistoryRecord {
        Status status;
        address actor;
        string location;
        uint256 timestamp;
    }

    address public admin;
    uint256 public productCount;

    mapping(address => bool) public participants;
    mapping(uint256 => Product) private products;
    mapping(uint256 => HistoryRecord[]) private history;

    event ParticipantAdded(address indexed participant);
    event ProductCreated(uint256 indexed id, string name, address indexed owner);
    event StatusUpdated(uint256 indexed id, Status status, address indexed actor, string location);
    event OwnershipTransferred(uint256 indexed id, address indexed from, address indexed to);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyParticipant() {
        require(participants[msg.sender], "Not a participant");
        _;
    }

    modifier productExists(uint256 id) {
        require(products[id].exists, "Product not found");
        _;
    }

    modifier onlyProductOwner(uint256 id) {
        require(products[id].owner == msg.sender, "Not product owner");
        _;
    }

    constructor() {
        admin = msg.sender;
        participants[msg.sender] = true;
        emit ParticipantAdded(msg.sender);
    }

    /// @notice Админ регистрирует участника цепочки (производитель, перевозчик, магазин)
    function addParticipant(address account) external onlyAdmin {
        require(account != address(0), "Zero address");
        participants[account] = true;
        emit ParticipantAdded(account);
    }

    /// @notice Создание новой партии товара
    function createProduct(string calldata name, string calldata metadataCID, string calldata location)
        external
        onlyParticipant
        returns (uint256 id)
    {
        require(bytes(name).length > 0, "Empty name");
        id = ++productCount;
        products[id] = Product(id, name, metadataCID, msg.sender, Status.Produced, true);
        history[id].push(HistoryRecord(Status.Produced, msg.sender, location, block.timestamp));
        emit ProductCreated(id, name, msg.sender);
        emit StatusUpdated(id, Status.Produced, msg.sender, location);
    }

    /// @notice Обновление статуса (только вперёд: Produced -> InTransit -> Delivered)
    function updateStatus(uint256 id, Status newStatus, string calldata location)
        external
        productExists(id)
        onlyProductOwner(id)
    {
        require(uint8(newStatus) == uint8(products[id].status) + 1, "Invalid status transition");
        products[id].status = newStatus;
        history[id].push(HistoryRecord(newStatus, msg.sender, location, block.timestamp));
        emit StatusUpdated(id, newStatus, msg.sender, location);
    }

    /// @notice Передача партии следующему участнику цепочки
    function transferOwnership(uint256 id, address to)
        external
        productExists(id)
        onlyProductOwner(id)
    {
        require(participants[to], "Receiver is not a participant");
        require(to != msg.sender, "Same owner");
        address from = products[id].owner;
        products[id].owner = to;
        emit OwnershipTransferred(id, from, to);
    }

    function getProduct(uint256 id) external view productExists(id) returns (Product memory) {
        return products[id];
    }

    function getHistory(uint256 id) external view productExists(id) returns (HistoryRecord[] memory) {
        return history[id];
    }
}
