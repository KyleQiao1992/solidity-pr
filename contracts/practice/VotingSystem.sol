// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VotingSystem {
    enum Vote {
        YES,
        NO,
        Abstain
    }

    //使用mapping记录每个地址的投票
    mapping(address => Vote) public votes;
    //查询是否投票
    mapping(address => bool) public hasVoted;
    // 使用uint统计每个选项的票数
    mapping(Vote => uint) public voteCounts;

    event Voted(address indexed voter, Vote vote);

    //投票函数
    function vote(Vote _vote) public {
        require(!hasVoted[msg.sender], "You have already voted");
        votes[msg.sender] = _vote;
        hasVoted[msg.sender] = true;

        voteCounts[_vote] += 1;

        emit Voted(msg.sender, _vote);
    }

    //查询结果
    function getResult() public view returns (uint, uint, uint) {
        return (
            voteCounts[Vote.YES],
            voteCounts[Vote.NO],
            voteCounts[Vote.Abstain]
        );
    }

    //查询我的结果
    function getMyVote() public view returns (Vote) {
        require(!hasVoted[msg.sender], "You have not voted");
        return votes[msg.sender];
    }

    function getTotalVoteCnt() public view returns (uint) {
        return
            voteCounts[Vote.YES] +
            voteCounts[Vote.NO] +
            voteCounts[Vote.Abstain];
    }
}
