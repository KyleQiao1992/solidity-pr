// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MultiSignWallet {
    // 自定义错误
    error NotOwner();
    error TxNotExists();
    error TxAlreadyExecuted();
    error TxAlreadyConfirmed();
    error InsufficientConfirmations();
    error ExecutionFailed();

    // 所有者列表
    address[] public owners;
    mapping(address => bool) public isOwner;

    // 所需确认数量
    uint256 public required;

    // 交易结构体
    struct Transaction {
        address to; // 目标地址
        uint256 value; // 发送的以太币数量
        bytes data; // 调用数据
        bool executed; // 是否已执行
        uint256 confirmations; // 确认数
    }

    // 交易列表
    Transaction[] public transactions;

    // 确认映射：交易ID => 所有者地址 => 是否已确认
    mapping(uint256 => mapping(address => bool)) public confirmations;

    // 事件
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Confirm(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);
    event ExecutionFailure(uint256 indexed txId);

    // 修饰符：只有所有者可以调用
    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    // 修饰符：交易必须存在
    modifier txExists(uint256 _txId) {
        if (_txId >= transactions.length) revert TxNotExists();
        _;
    }

    // 修饰符：交易未执行
    modifier notExecuted(uint256 _txId) {
        if (transactions[_txId].executed) revert TxAlreadyExecuted();
        _;
    }

    // 构造函数：初始化所有者和所需确认数
    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(
            _required > 0 && _required <= _owners.length,
            "Invalid required"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    // 接收以太币
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice 提交交易
     * @param _to 目标地址
     * @param _value 发送的以太币数量
     * @param _data 调用数据
     * @return 交易ID
     */
    function submit(
        address _to,
        uint256 _value,
        bytes memory _data
    ) external onlyOwner returns (uint256) {
        uint256 txId = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                confirmations: 0
            })
        );

        emit Submit(txId);
        return txId;
    }

    /**
     * @notice 确认交易
     * @param _txId 交易ID
     */
    function confirm(
        uint256 _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) {
        if (confirmations[_txId][msg.sender]) revert TxAlreadyConfirmed();

        confirmations[_txId][msg.sender] = true;
        transactions[_txId].confirmations += 1;

        emit Confirm(msg.sender, _txId);
    }

    /**
     * @notice 执行交易（使用call执行外部调用）
     * @param _txId 交易ID
     * @dev 使用call方法实现灵活性，可以调用任意合约的任意函数
     */
    function execute(
        uint256 _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) {
        Transaction storage transaction = transactions[_txId];

        // 检查确认数是否足够
        if (transaction.confirmations < required) {
            revert InsufficientConfirmations();
        }

        // 标记为已执行（防止重入）
        transaction.executed = true;

        // 使用call执行外部交易
        // call方法提供了灵活性，可以调用任意合约的任意函数
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

        if (success) {
            emit Execute(_txId);
        } else {
            // 执行失败，恢复状态
            transaction.executed = false;
            emit ExecutionFailure(_txId);
            revert ExecutionFailed();
        }
    }
}
