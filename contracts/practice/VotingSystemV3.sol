// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VotingSystemV3 {
    struct Vote {
        string description;
        uint256 voteCount;
        uint256 deadline;
        bool exists;
    }

    uint256 public voteCount;
    address public owner;

    mapping(uint256 => Vote) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    event ProposalCreated(uint256 proposalId, string description);
    event Voted(uint256 proposalId, address voter); 
    
    // 实现创建提案
    function createProposal(string memory description, uint durationDays) onlyOwner()
        public 
    {
        // 检查权限
        require(bytes(description).length > 0, "Description cannot be empty");
        require(durationDays > 0, "Duration must be greater than 0");

        // 验证参数
        uint256 proposalId = voteCount++;


        proposals[proposalId] = Vote({
            description: description,
            voteCount: 0,
            deadline: block.timestamp + (durationDays * 1 days),
            exists: true
        });
        
        emit ProposalCreated(proposalId, description);
    }
    
    // 实现投票
    function vote(uint proposalId) public {
        // 检查提案存在
        require(proposals[proposalId].exists, "Proposal does not exist");
        require(block.timestamp <= proposals[proposalId].deadline, "Voting period has ended");
        require(!hasVoted[proposalId][msg.sender], "You have already voted");

        // 检查是否已投票
        hasVoted[proposalId][msg.sender] = true;
        proposals[proposalId].voteCount += 1;

        emit Voted(proposalId, msg.sender);
    }
    
    // TODO: 获取获胜提案
    function getWinner() public view returns (uint winningProposalId) {
        // 遍历所有提案
        uint256 maxVotes = 0;
        // 找出票数最多的
        for(uint256 i=0;i<voteCount;i++){
            if(proposals[i].exists && proposals[i].voteCount > maxVotes){
                maxVotes = proposals[i].voteCount;
                winningProposalId = i;
            }
        }

        return winningProposalId;
    }
}
