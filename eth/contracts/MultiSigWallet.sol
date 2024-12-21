// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./IERC20.sol";

contract MultiSigWallet {

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
        uint numberConfirm;
        address initiator;
        uint256 initTime;
        uint256 executeTime;
    }

    mapping(uint => Transaction) public transactions;
    uint256 public transactionCount;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    event SubmitTransaction(address indexed owner, uint256 indexed transactionId, address indexed destination, uint256 value, bytes data);
    event ConfirmTransaction(address indexed owner, uint256 indexed transactionId);
    event RevokeConfirmation(address indexed owner, uint256 indexed transactionId);
    event ExecuteTransaction(address indexed owner, uint256 indexed transactionId);
    event ExecuteTransactionFailure(address indexed owner, uint256 indexed transactionId);
    event Deposited(address indexed sender, uint256 value);
    event Withdrawn(address indexed token, address indexed sender, address indexed receiver, uint256 amount);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier onlyWallet() {
        require(msg.sender == address(this),"No permit");
        _;
    }

    modifier transactionExists(uint transactionId) {
        require(transactions[transactionId].destination != address(0), "Transaction does not exist");
        _;
    }

    modifier confirmed(uint transactionId) {
        require(confirmations[transactionId][msg.sender], "Transaction not confirmed");
        _;
    }

    modifier notConfirmed(uint transactionId) {
        require(!confirmations[transactionId][msg.sender], "Transaction already confirmed");
        _;
    }

    modifier notExecuted(uint transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length && _required > _owners.length/2, "Invalid required number of confirmations");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    function submitTransaction(address destination, uint256 value, bytes memory data) public onlyOwner returns (uint256 transactionId){
        require(destination != address(0), "Transaction destination is zero address");
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false,
            numberConfirm: 0,
            initiator: msg.sender,
            initTime: block.timestamp,
            executeTime: 0
        });
        transactionCount += 1;
        emit SubmitTransaction(msg.sender, transactionId, destination, value, data);
        confirmTransaction(transactionId);
    }

    function confirmTransaction(uint256 transactionId) public onlyOwner transactionExists(transactionId) notExecuted(transactionId) notConfirmed(transactionId) {
        confirmations[transactionId][msg.sender] = true;
        transactions[transactionId].numberConfirm = transactions[transactionId].numberConfirm + 1;
        emit ConfirmTransaction(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    // @dev Allows anyone to execute a confirmed transaction. No verification required `confirmed(transactionId)`
    function executeTransaction(uint256 transactionId) public onlyOwner transactionExists(transactionId) notExecuted(transactionId) {
        if (isConfirmed(transactionId)) {
            Transaction storage transaction = transactions[transactionId];
            transaction.executed = true;
            (bool success,) = transaction.destination.call{value: transaction.value}(transaction.data);
            if (success) {
                transaction.executeTime = block.timestamp;
                emit ExecuteTransaction(msg.sender, transactionId);
            } else {
                emit ExecuteTransactionFailure(msg.sender, transactionId);
                transaction.executed = false;
            }
        }
    }

    function revokeConfirmation(uint256 transactionId) public onlyOwner transactionExists(transactionId) notExecuted(transactionId) confirmed(transactionId) {
        confirmations[transactionId][msg.sender] = false;
        emit RevokeConfirmation(msg.sender, transactionId);
    }

    function isConfirmed(uint256 transactionId) public view returns (bool){
        uint count = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count += 1;
            }
        }
        return count >= required;
    }

    function getOwners() public view returns (address[] memory){
        return owners;
    }

    function getConfirmationCount(uint transactionId) public view returns (uint256){
        uint256 count = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count += 1;
            }
        }
        return count;
    }

    // @dev Returns array with owner addresses, which confirmed transaction.
    function getConfirmations(uint transactionId) public view returns (address[] memory _confirmations){
        address[] memory confirmationsTemp = new address[](owners.length);
        uint count = 0;
        uint i;
        for (i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                confirmationsTemp[count] = owners[i];
                count += 1;
            }
        }
        _confirmations = new address[](count);
        for (i = 0; i < count; i++) {
            _confirmations[i] = confirmationsTemp[i];
        }
    }

    // @dev Returns list of transaction IDs in defined range.
    // @param from Index start position of transaction array.
    // @param to Index end position of transaction array.
    // @param pending Include pending transactions.
    // @param executed Include executed transactions.
    // @return Returns array of transaction IDs.
    function getTransactionIds(uint from, uint to, bool pending, bool executed) public view returns (uint[] memory _transactionIds){
        uint[] memory transactionIdsTemp = new uint[](transactionCount);
        uint count = 0;
        uint i;
        for (i = from; i < to; i++) {
            if (pending && !transactions[i].executed || executed && transactions[i].executed) {
                transactionIdsTemp[count] = i;
                count += 1;
            }
        }
        _transactionIds = new uint[](count);
        for (i = 0; i < count; i++) {
            _transactionIds[i] = transactionIdsTemp[i];
        }
    }


    function getTransaction(uint transactionId) public view returns (Transaction memory _tx){
        return transactions[transactionId];
    }

    function getTransactionId() public view returns (uint){
        return transactionCount;
    }

    function getRequired() public view returns (uint){
        return required;
    }

    function checkOwner(address owner) public view returns (bool){
        return isOwner[owner];
    }

    function withdraw(address token, address receiver, uint256 amount) public onlyWallet {
        if (token == address(0)) {
            payable(receiver).transfer(amount);
        } else {
            IERC20(token).transfer(receiver, amount);
        }
        emit Withdrawn(token, address(this), receiver, amount);
    }

    // @dev Fallback function allows to deposit ether.
    receive() external payable {
        if (msg.value > 0) {
            emit Deposited(msg.sender, msg.value);
        }
    }

}
