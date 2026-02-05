// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Ownable {
    address public owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract Pausable {
    bool public paused;

    event Paused(address account);
    event Unpaused(address account);

    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Pausable: not paused");
        _;
    }

    function _pause() internal whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }
}

contract MyContract is Ownable, Pausable {
    uint256 public value;

    function setValue(uint256 _value) public onlyOwner whenNotPaused {
        value = _value;
    }

    function emergencyPause() public onlyOwner {
        _pause();
    }

    function emergencyUnpause() public onlyOwner {
        _unpause();
    }
}
