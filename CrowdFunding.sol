// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFunding {
    enum State {
        Fundraising, //筹款中
        Successful, //成功
        Failed, //失败
        PaidOut //已支付
    }

    State public currentState = State.Fundraising;

    address public immutable creator;
    uint256 public immutable GOAL;
    uint256 public immutable DEADLINE;
    uint256 public immutable MIN_CONTRIBUTION = 0.01 ether;

    uint256 public totalFunded;
    uint256 public contributorCount;

    mapping(address => uint256) public contributions;
    address[] public contributors;

    //event
    event StateChanged(State oldState, State newState, uint timestamp);
    event Contribution(
        address indexed contributor,
        uint amount,
        uint totalFunded
    );
    event FundsWithdrawn(address indexed creator, uint amount);
    event Refunded(address indexed contributor, uint amount);

    modifier inState(State expectedState) {
        require(currentState == expectedState, "Invalid state for this action");
        _;
    }

    modifier onlyCreator() {
        require(msg.sender == creator, "Only creator can perform this action");
        _;
    }

    constructor(uint goalAmount, uint durationDays) {
        require(goalAmount > 0, "Goal must be positive");
        require(durationDays >= 1 && durationDays <= 90, "Duration: 1-90 days");
        
        CREATOR = msg.sender;
        GOAL = goalAmount;
        DEADLINE = block.timestamp + (durationDays * 1 days);
    }

    //贡献资金
    fucntion constribute()public payable inState(State.Fundraising){
        require(block.timestamp<=DEADLINE,"Fundraising period over");
        require(msg.value>=MIN_CONTRIBUTION,"Below minimum contribution");

        if(contributions[msg.sender]==0){
            contributors.push(msg.sender);
            contributorCount++;
        }

        contributions[msg.sender]+=msg.value;
        totalFunded+=msg.value;

        emit Contribution(msg.sender, msg.value, totalFunded);

        if(totalFunded>=GOAL){
            currentState=State.Successful;
            emit StateChanged(State.Fundraising, State.Successful, block.timestamp);

        }
    }

    //检查并更新状态
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


    //创建者提取资金
    function withdrawFunds() public onlyCreator inState(State.Successful) {
        currentState = State.PaidOut;

         uint amount = address(this).balance;
        (bool sent, ) = CREATOR.call{value: amount}("");
        require(sent, "Transfer failed");
        
        emit FundsWithdrawn(CREATOR, amount);
    }

    constructor(uint256 _goalAmount, uint256 _durationDays) {
        require(_goalAmount > 0, "Goal must be positive");
        require(
            _durationDays > 1 && _durationDays <= 90,
            "Duration: 1-90 days"
        );

        creator = msg.sender;
        GOAL = _goalAmount;
        DEADLINE = block.timestamp + _durationDays * 1 days;
    }

     // 退款
    function refund() public inState(State.Failed) {
        uint amount = contributions[msg.sender];
        require(amount > 0, "No contribution");
        
        contributions[msg.sender] = 0;
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Refund failed");
        
        emit Refunded(msg.sender, amount);
    }

    // 查询函数
    function getInfo()
        public
        view
        returns (
            State state,
            uint goal,
            uint funded,
            uint deadline,
            uint timeRemaining,
            uint contributorCount
        )
    {
        uint remaining = 0;
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
