// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFunding {
    enum State {
        Fundraising,
        Successful,
        Failed,
        PaidOut
    }

    State public currentState = State.Fundraising;

    address public immutable creator;
    uint256 public immutable GOAL;
    uint256 public immutable DEADLINE;
    uint256 public constant MIN_CONTRIBUTION = 0.01 ether;

    uint256 public totalFunded;
    uint256 public contributorCount;

    mapping(address => uint256) public contributions;
    address[] public contributors;

    event StateChanged(State oldState, State newState, uint256 timestamp);
    event Contribution(
        address indexed contributor,
        uint256 amount,
        uint256 totalFunded
    );
    event FundsWithdrawn(address indexed creator, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);

    modifier inState(State expectedState) {
        require(currentState == expectedState, "Invalid state for this action");
        _;
    }

    modifier onlyCreator() {
        require(msg.sender == creator, "Only creator can perform this action");
        _;
    }

    constructor(uint256 goalAmount, uint256 durationDays) {
        require(goalAmount > 0, "Goal must be positive");
        require(durationDays >= 1 && durationDays <= 90, "Duration: 1-90 days");

        creator = msg.sender;
        GOAL = goalAmount;
        DEADLINE = block.timestamp + (durationDays * 1 days);
    }

    function contribute() public payable inState(State.Fundraising) {
        require(block.timestamp <= DEADLINE, "Fundraising period over");
        require(msg.value >= MIN_CONTRIBUTION, "Below minimum contribution");

        if (contributions[msg.sender] == 0) {
            contributors.push(msg.sender);
            contributorCount++;
        }

        contributions[msg.sender] += msg.value;
        totalFunded += msg.value;

        emit Contribution(msg.sender, msg.value, totalFunded);

        if (totalFunded >= GOAL) {
            currentState = State.Successful;
            emit StateChanged(State.Fundraising, State.Successful, block.timestamp);
        }
    }

    function checkGoalReached() public inState(State.Fundraising) {
        require(block.timestamp >= DEADLINE, "Fundraising still ongoing");

        if (totalFunded >= GOAL) {
            currentState = State.Successful;
            emit StateChanged(State.Fundraising, State.Successful, block.timestamp);
        } else {
            currentState = State.Failed;
            emit StateChanged(State.Fundraising, State.Failed, block.timestamp);
        }
    }

    function withdrawFunds() public onlyCreator inState(State.Successful) {
        currentState = State.PaidOut;

        uint256 amount = address(this).balance;
        (bool sent, ) = creator.call{value: amount}("");
        require(sent, "Transfer failed");

        emit FundsWithdrawn(creator, amount);
    }

    function refund() public inState(State.Failed) {
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution");

        contributions[msg.sender] = 0;
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Refund failed");

        emit Refunded(msg.sender, amount);
    }

    function getInfo()
        public
        view
        returns (
            State state,
            uint256 goal,
            uint256 funded,
            uint256 deadline,
            uint256 timeRemaining,
            uint256 contributorsNum
        )
    {
        uint256 remaining = 0;
        if (block.timestamp < DEADLINE) {
            remaining = DEADLINE - block.timestamp;
        }

        return (
            currentState,
            GOAL,
            totalFunded,
            DEADLINE,
            remaining,
            contributorCount
        );
    }

    function getProgress() public view returns (uint256 percentage) {
        return (totalFunded * 100) / GOAL;
    }

    function isActive() public view returns (bool) {
        return currentState == State.Fundraising && block.timestamp <= DEADLINE;
    }
}
