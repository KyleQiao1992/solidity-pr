// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UserManagementSystem {
    struct User {
        string name;
        string email;
        uint256 balance;
        uint256 registeredAt;
        bool exists;
    }
    // TODO: 定义数据存储
    mapping(address => User) public users;
    address[] public userAddresses;
    uint256 public userCount;
    uint256 public constant MAX_USERS = 1000;

    event UserRegistered(address indexed user, string name);
    event UserUpdated(address indexed user);
    event Deposit(address indexed user, uint256 amount);

    //用户注册
    function register(string memory name, string memory email) public {
        require(!users[msg.sender].exists, "Already registered");
        require(userCount < MAX_USERS, "Max users reached");
        require(bytes(name).length > 0, "Name is required");
        require(bytes(email).length > 0, "Email is required");

        users[msg.sender] = User({
            name: name,
            email: email,
            balance: 0,
            registeredAt: block.timestamp,
            exists: true
        });

        userAddresses.push(msg.sender);
        userCount++;
        emit UserRegistered(msg.sender, name);
    }

    //更新
    function updateProfile(string memory name, string memory email) public {
        require(users[msg.sender].exists, "Not registered");
        require(bytes(name).length > 0, "Name is required");
        require(bytes(email).length > 0, "Email is required");

        users[msg.sender].name = name;
        users[msg.sender].email = email;
        emit UserUpdated(msg.sender);
    }

    //存钱
    function deposit() public payable {
        require(users[msg.sender].exists, "Not registered");
        require(msg.value > 0, "Must send ETH more than 0");
        users[msg.sender].balance += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    //获取用户信息
    function getUserInfo(address user) public view returns (User memory) {
        require(users[user].exists, "User not registered");
        return users[user];
    }

    //获取全部用户信息
    function getAllUsers() public view returns (address[] memory) {
        return userAddresses;
    }

    //获取范围内的用户信息
    function getUsersByRange(
        uint256 start,
        uint256 end
    ) public view returns (address[] memory) {
        require(start < end, "Invalid input");
        require(end <= userAddresses.length, "Invalid input");

        uint256 length = end - start;
        address[] memory res = new address[](length);

        for (uint i = 0; i < length; i++) {
            res[i] = userAddresses[start + i];
        }
        return res;
    }

    //判断用户是否注册
    function isRegistered(address user) public view returns (bool) {
        return users[user].exists;
    }
}
