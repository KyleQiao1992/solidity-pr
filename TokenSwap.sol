// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 代币交换合约
// 代币交换是DeFi中最常见的应用场景。在代币交换合约中，我们需要调用ERC20合约来实现代币的转移

interface IERC20P {
    function transfer(address to, uint256 amount) external returns (bool);
// 授权函数
    function approve(address spender, uint256 amount) external returns (bool);

// 转移函数
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
}

contract TokenSwap {
    IERC20 public tokenA;
    IERC20 public tokenB;

    // 交换比例（简化示例，使用固定比例）
    uint256 public exchangeRate = 1; //1:1 // 1 TokenA = exchangeRate * TokenB

    // 事件：记录每次交换的详细信息
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    // 构造函数：初始化代币合约地址
    constructor(address _tokenA, address _tokenB) {
        // 将地址转换为接口类型，确保类型安全
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);

        uint256 contractBalanceB = tokenB.balanceOf(address(this));
        uint256 amountB = amountA * exchangeRate;
        require(
            contractBalanceB >= amountB,
            "Insufficient token B in contract"
        );

        // 步骤2：从用户账户转移tokenA到本合约
        // transferFrom需要用户先调用tokenA.approve授权本合约
        // 使用接口调用，编译器会检查参数类型
        require(
            tokenA.transferFrom(msg.sender, address(this), amountA),
            "Transfer of token A failed";
        );
        
        // 步骤3：从本合约向用户转移tokenB
        // 使用接口调用，确保类型安全

        require(tokenB.transfer(msg.sender,amountB),"TokenB transfer failed");

         // 步骤4：触发事件，记录交换信息
        // 前端应用可以监听这个事件来更新UI
        emit Swap(msg.sender, address(tokenA), address(tokenB), amountA, amountB);
    }

    /**
     * @notice 执行代币交换
     * @param amountA 要交换的tokenA数量
     * @dev 用户需要先调用tokenA的approve函数授权本合约
     */
    function swap(uint256 amoutA) external {
        // 步骤1：检查合约是否有足够的tokenB用于交换
        // 使用接口的view函数查询余额，不消耗Gas
    }

    /**
     * @notice 查询合约持有的代币余额
     */
    function getContractBalances()
        external
        view
        returns (uint256 balanceA, uint256 balanceB)
    {
        // 使用接口的view函数查询余额
        balanceA = tokenA.balanceOf(address(this));
        balanceB = tokenB.balanceOf(address(this));
    }
}
