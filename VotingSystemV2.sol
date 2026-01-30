// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VotingSystemV2 {
    struct Proposal {
        string description;
        uint256 voteCount;
        uint256 deadline;
        bool executed;
        mapping(address => bool) voters;
    }

    //key: proposalId
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    event ProposalCreated(uint256 indexed proposalId, string description);
    event Voted(uint256 indexed proposalId, address indexed voter);

    //创建提案
    function createProposal(
        string memory _description,
        uint256 _duration
    ) public returns (uint256) {
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_duration > 0, "Deadline must be in the future");

        uint256 proposalId = proposalCount++;

        Proposal storage p = proposals[proposalId];
        p.description = _description;
        p.voteCount = 0;
        p.deadline = block.timestamp + _duration;
        p.executed = false;

        emit ProposalCreated(proposalId, _description);

        return proposalId;
    }

    function vote(uint256 proposalId) public {
        require(proposalId < proposalCount, "Invalid proposal ID");

        Proposal storage p = proposals[proposalId];

        require(block.timestamp < p.deadline, "Voting period has ended");
        require(!p.voters[msg.sender], "User already voted");

        p.voteCount += 1;
        p.voters[msg.sender] = true;
        emit Voted(proposalId, msg.sender);
    }

    function hasVoted(
        uint256 proposalId,
        address voter
    ) public view returns (bool) {
        require(proposalId < proposalCount, "Invalid proposal ID");
        return proposals[proposalId].voters[voter];
    }

    function getProposalInfo(
        uint256 proposalId
    )
        public
        view
        returns (
            string memory description,
            uint256 voteCount,
            uint256 deadline,
            bool executed
        )
    {
        require(proposalId < proposalCount, "Invalid proposal ID");

        Proposal storage p = proposals[proposalId];

        return (p.description, proposalCount, p.deadline, p.executed);
    }

    function getWinningProposal() public view returns (uint256 res) {
        uint256 maxVotes = 0;

        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].voteCount > maxVotes) {
                maxVotes = proposals[i].voteCount;
                res = i;
            }
        }
        return res;
    }
}
