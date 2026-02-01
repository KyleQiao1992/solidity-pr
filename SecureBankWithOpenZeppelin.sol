// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 导入OpenZeppelin的ReentrancyGuard
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// 使用OpenZeppelin重入锁的银行合约
contract SecureBankWithOpenZeppelin is ReentrancyGuard {
    mapping(address => uint256) public balances;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    
    /**
     * @notice 存款函数
     */
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @notice 安全的提现函数：使用OpenZeppelin的nonReentrant修饰符
     * @dev OpenZeppelin的实现经过充分审计，更安全可靠
     */
    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");
        
        balances[msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdrawal(msg.sender, amount);
    }
}