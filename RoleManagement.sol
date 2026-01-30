// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RoleManagement {
    enum Role {
        NONE,
        USER,
        ADMIN,
        Owner
    }

    mapping(address => Role) public roles;

    address public owner;

    event RoleAssigned(address indexed user, Role role);
    event RoleRevoked(address indexed user);

    constructor() {
        owner = msg.sender;
        roles[owner] = Role.Owner;
    }

    // TODO: 定义modifier
    modifier onlyOwner() {
        // 检查是否为Owner
        require(
            roles[msg.sender] == Role.Owner,
            "Only owner can perform this action"
        );
        _;
    }

    modifier onlyAdmin() {
        // 检查是否为Admin或Owner
        require(
            roles[msg.sender] == Role.ADMIN || roles[msg.sender] == Role.Owner,
            "Only amdmin can perform this action"
        );
        _;
    }

    modifier onlyUser() {
        require(roles[msg.sender] != Role.NONE, "Must have a role");
        _;
    }

    // TODO: 实现功能函数
    function addAdmin(address user) public onlyOwner {
        // Owner添加Admin
        require(user != address(0), "Invalid input");
        require(
            roles[user] != Role.ADMIN && roles[user] != Role.Owner,
            "User is already an admin"
        );

        roles[user] = Role.ADMIN;
        emit RoleAssigned(user, Role.ADMIN);
    }

    function addUser(address user) public onlyAdmin {
        // Admin添加User
        require(user != address(0), "Invalid input");
        require(roles[user] == Role.NONE, "User already has a role");

        roles[user] = Role.USER;
        emit RoleAssigned(user, Role.USER);
    }

    function getRole(address user) public view returns (Role) {
        // 查询角色
        return roles[user];
    }

    function revokeRole(address user) public onlyOwner {
        require(user != owner, "Cannot revoke owner role");
        delete roles[user];
        emit RoleRevoked(user);
    }

    function hasRole(address user, Role role) public view returns (bool) {
        return roles[user] == role;
    }
}
