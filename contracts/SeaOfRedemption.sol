//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

contract SeaOfRedemption is Ownable, ReentrancyGuard {
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
    uint256 public amountOfStakedTokens;
    
    EnumerableSet.UintSet excludedTokens;
    EnumerableSet.AddressSet stakers;
    mapping(address => UserInfo) private userInfo;

    event RewardRateUpdate(uint256 oldValue, uint256 newValue);
    event Stake(address indexed account, uint256[] tokenId);
    event Claim(address indexed account, uint256 amount);
    event InsufficientReward(address indexed account, uint256 amountNeeded, uint256 balance);
    
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
    
    receive() external payable {}
    
    function setLottery(IERC721 _lottery) external onlyOwner {
        lottery = _lottery;
    }
    
    function addExcludedToken(uint256 _tokenId) external onlyLottery {
        excludedTokens.add(_tokenId);
    }
    
    function stake(uint256[] memory _tokenIds) external nonReentrant {
        if (!stakers.contains(msg.sender)) {
            stakers.add(msg.sender);
            require(
                stakers.length() <= maxAmountOfStakers,
                "max amount of stakers has been reached"
            );
        }
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(
                msg.sender == lottery.ownerOf(_tokenIds[i]),
                "sender is not the owner"
            );
            require(
                !excludedTokens.contains(_tokenIds[i]),
                "contains excluded token"
            );
            lottery.transferFrom(
                msg.sender,
                address(this),
                _tokenIds[i]
            );
        }
        UserInfo storage user = userInfo[msg.sender];
        if (user.tokens.length() != 0) {
            claim();
        } else {
            user.lastTimeRewardClaimed = block.timestamp;
        }
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            user.tokens.add(_tokenIds[i]);
            user.avaibleClaimsPerToken[_tokenIds[i]] = maxClaims;
        }
        amountOfStakedTokens += _tokenIds.length;
        emit Stake(msg.sender, _tokenIds);
    }
    
    function updateRewardRate(uint256 _rewardRate) external onlyOwner {
        require(
            _rewardRate > 0,
            "invalid reward rate"
        );
        rewardRate = _rewardRate;
        emit RewardRateUpdate(rewardRate, _rewardRate);
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
        uint256 amountSent = safeRewardTransfer(msg.sender, pendingAmount);
        user.rewards = pendingAmount - amountSent;
        for (uint256 i = 0; i < user.tokens.length(); i++) {
            uint256 tokenId = user.tokens.at(i);
            user.avaibleClaimsPerToken[tokenId]--;
            if (user.avaibleClaimsPerToken[tokenId] == 0) {
                user.tokens.remove(tokenId);
                excludedTokens.add(tokenId);
                amountOfStakedTokens--;
            }
        }
        if (user.tokens.length() == 0) {
            stakers.remove(msg.sender);
        }
        user.lastTimeRewardClaimed = block.timestamp;
        emit Claim(msg.sender, amountSent);
    }
    
    function pendingRewards(address _account) public view returns (uint256) {
        UserInfo storage user = userInfo[_account];
        uint256 timeBetween = block.timestamp - user.lastTimeRewardClaimed;
        uint256 amount = (timeBetween * userStakedNFTCount(_account) * rewardRate * 1e12) / amountOfStakedTokens;
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
        address _account,
        uint256 _index
    )
        public
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[_account];
        return user.tokens.at(_index);
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
        emit InsufficientReward(_to, _amount, balance);
        return balance;
    }
}
