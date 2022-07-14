//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import "hardhat/console.sol";

contract KingsCastle is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    
    struct UserInfo {
        EnumerableSet.UintSet tokens;
        mapping(uint256 => uint256) avaibleClaimsPerToken;
        uint256 rewards;
        uint256 lastTimeRewardClaimed;
    }

    IERC721 public lottery;
    uint256 public rewardRate;
    uint256 public maxClaims;
    uint256 public maxAmountOfStakers;
    
    EnumerableSet.UintSet winningTokens;
    EnumerableSet.AddressSet stakers;
    mapping(address => UserInfo) private userInfo;

    event RewardPerBlockUpdated(uint256 oldValue, uint256 newValue);
    event Staked(address indexed account, uint256 tokenId);
    event Harvested(address indexed account, uint256 amount);
    event InsufficientRewardToken(address indexed account, uint256 amountNeeded, uint256 balance);
    
    modifier onlyLottery() {
        require(
            msg.sender == address(lottery),
            "only lottery can call this function"
        );
        _;
    }

    constructor(
        address _owner,
        uint256 _rewardRate,
        uint256 _maxClaims,
        uint256 _maxAmountOfStakers
    )
        Ownable()
    {
        transferOwnership(_owner);
        rewardRate = _rewardRate;
        maxClaims = _maxClaims;
        maxAmountOfStakers = _maxAmountOfStakers;
    }
    
    receive() external payable onlyLottery {}
    
    function setLottery(IERC721 _lottery) external onlyOwner {
        lottery = _lottery;
    }
    
    function addWinningToken(uint256 _tokenId) external onlyLottery {
        winningTokens.add(_tokenId);
    }
    
    function stake(uint256 _tokenId) external nonReentrant {
        require(
            msg.sender == lottery.ownerOf(_tokenId),
            "sender is not the owner"
        );
        require(
            winningTokens.contains(_tokenId),
            "not a winning ticket"
        );
        if (!stakers.contains(msg.sender)) {
            stakers.add(msg.sender);
            require(
                stakers.length() <= maxAmountOfStakers,
                "max amount of stakers has been reached"
            );
        }
        lottery.transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );
        UserInfo storage user = userInfo[msg.sender];
        if (user.tokens.length() != 0) {
            claim();
        } else {
            user.lastTimeRewardClaimed = block.timestamp;
        }
        user.tokens.add(_tokenId);
        user.avaibleClaimsPerToken[_tokenId] = maxClaims;
        emit Staked(msg.sender, _tokenId);
    }
    
    function updateRewardRate(uint256 _rewardRate) external onlyOwner {
        require(
            _rewardRate > 0,
            "invalid reward rate"
        );
        rewardRate = _rewardRate;
        emit RewardPerBlockUpdated(rewardRate, _rewardRate);
    }

    function viewUserInfo(
        address __account
    )
        external
        view
        returns (
            uint256[] memory tokens,
            uint256[] memory avaibleClaimsPerToken,
            uint256 rewards,
            uint256 lastTimeRewardClaimed
        )
    {
        UserInfo storage user = userInfo[__account];
        rewards = user.rewards;
        lastTimeRewardClaimed = user.lastTimeRewardClaimed;
        uint256 amountOfTokens = user.tokens.length();
        if (amountOfTokens == 0) {
            tokens = new uint256[](0);
            avaibleClaimsPerToken = new uint256[](0);
        } else {
            tokens = new uint256[](amountOfTokens);
            avaibleClaimsPerToken = new uint256[](amountOfTokens);
            uint256 index;
            for (index = 0; index < amountOfTokens; index++) {
                tokens[index] = tokenOfOwnerByIndex(__account, index);
                avaibleClaimsPerToken[index] = user.avaibleClaimsPerToken[tokens[index]];
            }
        }
    }
    
    function claim() public {
        require(
            stakers.contains(msg.sender),
            "forbidden to claim"
        );
        UserInfo storage user = userInfo[msg.sender];
        uint256 pendingAmount = pendingRewards(msg.sender);
        if (pendingAmount > 0) {
            uint256 amountSent = safeRewardTransfer(msg.sender, pendingAmount);
            user.rewards = pendingAmount - amountSent;
            emit Harvested(msg.sender, amountSent);
        }
        for (uint256 i = 0; i < user.tokens.length(); i++) {
            uint256 tokenId = user.tokens.at(i);
            user.avaibleClaimsPerToken[tokenId]--;
            uint256 avaibleClaims = user.avaibleClaimsPerToken[tokenId];
            if (avaibleClaims == 0) {
                user.tokens.remove(tokenId);
                winningTokens.remove(tokenId);
            }
        }
        if (user.tokens.length() == 0) {
            stakers.remove(msg.sender);
        }
        user.lastTimeRewardClaimed = block.timestamp;
    }
    
    function pendingRewards(address _account) public view returns (uint256) {
        UserInfo storage user = userInfo[_account];
        uint256 timeBetween = block.timestamp - user.lastTimeRewardClaimed;
        uint256 amount = timeBetween * userStakedNFTCount(_account) * rewardRate * 1e12 / winningTokens.length();
        return user.rewards + amount / 1e12;
    }
    
    function userStakedNFTCount(
        address __account
    )
        public
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[__account];
        return user.tokens.length();
    }

    function tokenOfOwnerByIndex(
        address __account,
        uint256 __index
    )
        public
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[__account];
        return user.tokens.at(__index);
    }

    function safeRewardTransfer(address _to, uint256 _amount) internal returns (uint256) {
        uint256 balance = address(this).balance;
        if (balance >= _amount) {
            payable(_to).transfer(_amount);
            return _amount;
        }
        if (balance > 0) {
            payable(_to).transfer(balance);
        }
        emit InsufficientRewardToken(_to, _amount, balance);
        return balance;
    }
}
