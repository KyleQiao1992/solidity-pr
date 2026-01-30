// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SafeArrayManager {
    uint[] public data;
    uint public constant MAX_SIZE = 100;

    event ElementAdded(uint value, uint index);
    event ElementRemoved(uint index, uint value);

    // TODO: 实现以下功能

    // 1. 安全添加
    function safePush(uint value) public {
        // 检查大小限制
        uint length = data.length;
        require(length < MAX_SIZE, "Array is full");
        // 添加元素
        data.push(value);

        emit ElementAdded(value, length - 1);
    }

    // 2. 保序删除
    function removeOrdered(uint index) public {
        // 检查索引
        uint length = data.length;
        require(index < length, "Index out of bounds");

        // 移动元素
        for (uint i = index; i < length - 1; i++) {
            uint lastElement = data[i + 1];
            data[i] = lastElement;
        }
        // pop最后元素
        data.pop();
        emit ElementRemoved(index, data[index]);
    }

    // 3. 快速删除
    function removeUnordered(uint index) public {
        uint length = data.length;
        // 检查索引
        require(index < length, "Index out of bounds");
        uint removeValue = data[index];

        // 替换为最后元素
        uint lastElement = data[length - 1];
        data[index] = lastElement;
        // pop
        data.pop();

        emit ElementRemoved(index, removeValue);
    }

    // 4. 分批求和
    function sumRange(uint start, uint end) public view returns (uint) {
        // 检查范围
        uint length = data.length;
        require(start < end, "Invalid Input");
        require(end < length, "End out of Bounds");

        uint total = 0;
        // 计算总和
        for (uint i = start; i < end; i++) {
            total += data[i];
        }

        return total;
    }

    // 5. 查找元素
    function findElement(uint value) public view returns (bool, uint) {
        uint length = data.length;
        // 遍历查找
        for (uint i; i < length; i++) {
            if (data[i] == value) {
                return (true, i);
            }
        }
        // 返回是否找到和索引
        return (false, 0);
    }

    // 6. 获取所有元素
    function getAll() public view returns (uint[] memory) {
        // 返回整个数组
        return data;
    }
}
