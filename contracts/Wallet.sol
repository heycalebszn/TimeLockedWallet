// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    address[] public owners;
    uint256 public requiredApprovals;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvals;
    }

    mapping(uint256 => mapping(address => bool)) public isApproved;
    Transaction[] public transactions;

    event Deposit(address indexed sender, uint256 amount);
    event SubmitTransaction(address indexed owner, uint256 indexed txId);
    event ApproveTransaction(address indexed owner, uint256 indexed txId);
    event RevokeApproval(address indexed owner, uint256 indexed txId);
    event ExecuteTransaction(address indexed owner, uint256 indexed txId);

    modifier onlyOwner() {
        require(isOwner(msg.sender), "Not an owner");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notApproved(uint256 _txId) {
        require(!isApproved[_txId][msg.sender], "Transaction already approved");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredApprovals) {
        require(_owners.length > 0, "Owners required");
        require(
            _requiredApprovals > 0 && _requiredApprovals <= _owners.length,
            "Invalid required approvals"
        );

        owners = _owners;
        requiredApprovals = _requiredApprovals;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            approvals: 0
        }));

        emit SubmitTransaction(msg.sender, transactions.length - 1);
    }

    function approveTransaction(uint256 _txId)
        public
        onlyOwner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
    {
        isApproved[_txId][msg.sender] = true;
        transactions[_txId].approvals++;

        emit ApproveTransaction(msg.sender, _txId);
    }

    function revokeApproval(uint256 _txId)
        public
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
    {
        require(isApproved[_txId][msg.sender], "Transaction not approved");
        isApproved[_txId][msg.sender] = false;
        transactions[_txId].approvals--;

        emit RevokeApproval(msg.sender, _txId);
    }

    function executeTransaction(uint256 _txId)
        public
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
    {
        require(
            transactions[_txId].approvals >= requiredApprovals,
            "Not enough approvals"
        );

        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txId);
    }

    function isOwner(address _account) internal view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _account) {
                return true;
            }
        }
        return false;
    }

    function getTransaction(uint256 _txId)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 approvals
        )
    {
        Transaction memory transaction = transactions[_txId];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.approvals
        );
    }
}