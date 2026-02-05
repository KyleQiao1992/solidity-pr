// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract TokenSwap {
    IERC20 public tokenA;
    IERC20 public tokenB;

    // 1 TokenA = exchangeRate * TokenB
    uint256 public exchangeRate = 1;

    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0), "Invalid tokenA");
        require(_tokenB != address(0), "Invalid tokenB");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function swap(uint256 amountA) external {
        require(amountA > 0, "Amount must be greater than 0");

        uint256 amountB = amountA * exchangeRate;
        uint256 contractBalanceB = tokenB.balanceOf(address(this));
        require(contractBalanceB >= amountB, "Insufficient token B in contract");

        require(
            tokenA.transferFrom(msg.sender, address(this), amountA),
            "Transfer of token A failed"
        );
        require(
            tokenB.transfer(msg.sender, amountB),
            "Transfer of token B failed"
        );

        emit Swap(msg.sender, address(tokenA), address(tokenB), amountA, amountB);
    }

    function getContractBalances()
        external
        view
        returns (uint256 balanceA, uint256 balanceB)
    {
        balanceA = tokenA.balanceOf(address(this));
        balanceB = tokenB.balanceOf(address(this));
    }
}
