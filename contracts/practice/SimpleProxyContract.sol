// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract LogicalContract {
    // 注意：这些变量的存储位置必须与代理合约匹配
    uint256 public value;
    address public owner;

     // 设置值的函数
    function setValue(uint256 _value) external {
        // 这个函数会修改调用者合约的storage
        value = _value;
        owner = msg.sender;  // msg.sender是原始调用者，不是代理合约
    }
    
    // 获取值的函数
    function getValue() external view returns (uint256) {
        return value;
    }
}


// 代理合约：存储数据，通过delegatecall调用逻辑合约
contract SimpleProxyContract {
 // 存储布局必须与LogicContract完全一致
 
    uint256 public value;           // 与LogicContract的value对应
    address public owner;            // 与LogicContract的owner对应
    
    address public implementation;  // 逻辑合约地址
    
    event Upgraded(address indexed newImplementation);
    
    constructor(address _implementation) {
        implementation = _implementation;
        owner = msg.sender;
    }
    
    // fallback函数：将所有调用转发到逻辑合约
    fallback() external payable {
        address impl = implementation;
        require(impl != address(0), "Implementation not set");
        
        // 使用delegatecall调用逻辑合约
        // 逻辑合约的代码会在本合约的上下文中执行
        (bool success, bytes memory returnData) = impl.delegatecall(msg.data);
        
        if (!success) {
            // 如果调用失败，回滚
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        
        // 返回数据
        assembly {
            return(add(returnData, 0x20), mload(returnData))
        }
    }
    
     // 升级函数：更换逻辑合约
    function upgrade(address newImplementation) external {
        require(msg.sender == owner, "Not owner");
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }
}
