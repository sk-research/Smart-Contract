// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Crowdfunding {
    struct Project {
        address creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 deadline;
        uint256 fundsRaised;
        bool completed;
        mapping(address => uint256) contributions;
        Milestone[] milestones;
        uint256 currentMilestone;
    }
    
    struct Milestone {
        string description;
        uint256 amount;
        bool approved;
        uint256 approvals;
        mapping(address => bool) voters;
    }
    
    mapping(uint256 => Project) public projects;
    uint256 public projectCount;
    
    event ProjectCreated(uint256 projectId, address creator, uint256 goalAmount, uint256 deadline);
    event Funded(uint256 projectId, address contributor, uint256 amount);
    event MilestoneApproved(uint256 projectId, uint256 milestoneId);
    event Withdraw(uint256 projectId, uint256 milestoneId, uint256 amount);
    
    function createProject(
        string memory title,
        string memory description,
        uint256 goalAmount,
        uint256 durationInDays,
        string[] memory milestoneDescriptions,
        uint256[] memory milestoneAmounts
    ) external {
        require(milestoneDescriptions.length == milestoneAmounts.length, "Mismatched milestones");
        uint256 projectId = projectCount++;
        Project storage project = projects[projectId];
        project.creator = msg.sender;
        project.title = title;
        project.description = description;
        project.goalAmount = goalAmount;
        project.deadline = block.timestamp + (durationInDays * 1 days);
        project.completed = false;
        
        for (uint256 i = 0; i < milestoneDescriptions.length; i++) {
            project.milestones.push(Milestone({
                description: milestoneDescriptions[i],
                amount: milestoneAmounts[i],
                approved: false,
                approvals: 0
            }));
        }
        
        emit ProjectCreated(projectId, msg.sender, goalAmount, project.deadline);
    }
    
    function fundProject(uint256 projectId) external payable {
        Project storage project = projects[projectId];
        require(block.timestamp < project.deadline, "Project funding closed");
        require(!project.completed, "Project already completed");
        
        project.fundsRaised += msg.value;
        project.contributions[msg.sender] += msg.value;
        
        emit Funded(projectId, msg.sender, msg.value);
    }
    
    function approveMilestone(uint256 projectId) external {
        Project storage project = projects[projectId];
        require(block.timestamp < project.deadline, "Project deadline passed");
        require(!project.completed, "Project already completed");
        
        uint256 milestoneId = project.currentMilestone;
        require(milestoneId < project.milestones.length, "No more milestones");
        Milestone storage milestone = project.milestones[milestoneId];
        require(!milestone.approved, "Milestone already approved");
        require(project.contributions[msg.sender] > 0, "Only contributors can vote");
        require(!milestone.voters[msg.sender], "Already voted");
        
        milestone.voters[msg.sender] = true;
        milestone.approvals++;
        
        if (milestone.approvals * 2 > project.fundsRaised / 1 ether) {
            milestone.approved = true;
            emit MilestoneApproved(projectId, milestoneId);
        }
    }
    
    function withdrawFunds(uint256 projectId) external {
        Project storage project = projects[projectId];
        require(msg.sender == project.creator, "Only creator can withdraw");
        require(!project.completed, "Project already completed");
        
        uint256 milestoneId = project.currentMilestone;
        require(milestoneId < project.milestones.length, "No more milestones");
        Milestone storage milestone = project.milestones[milestoneId];
        require(milestone.approved, "Milestone not approved yet");
        
        uint256 amount = milestone.amount;
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        payable(msg.sender).transfer(amount);
        project.currentMilestone++;
        
        if (project.currentMilestone == project.milestones.length) {
            project.completed = true;
        }
        
        emit Withdraw(projectId, milestoneId, amount);
    }
    
    function refund(uint256 projectId) external {
        Project storage project = projects[projectId];
        require(block.timestamp > project.deadline, "Project still active");
        require(project.fundsRaised < project.goalAmount, "Project reached goal");
        require(project.contributions[msg.sender] > 0, "No contribution found");
        
        uint256 refundAmount = project.contributions[msg.sender];
        project.contributions[msg.sender] = 0;
        payable(msg.sender).transfer(refundAmount);
    }
}
