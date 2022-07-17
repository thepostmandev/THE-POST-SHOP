//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import "./interfaces/ILottery.sol";

contract KingsCastle is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    
    struct UserInfo {
        EnumerableSet.UintSet tokens;
        mapping(uint256 => uint256) avaibleClaimsPerToken;
        uint256 rewards;
        uint256 lastTimeRewardClaimed;
    }

    uint256 public rewardRate;
    uint256 public maxClaims;
    uint256 public maxAmountOfStakers;
    uint256 public amountOfStakedTokens;
    address public lottery;
    
    EnumerableSet.UintSet private winningTokens;
    EnumerableSet.AddressSet private stakers;
    mapping(address => UserInfo) private userInfo;

    event RewardRateUpdate(uint256 oldValue, uint256 newValue);
    event Stake(address indexed account, uint256 tokenId);
    event Claim(address indexed account, uint256 amount);
    event InsufficientReward(address indexed account, uint256 amountNeeded, uint256 balance);
    
    modifier onlyLottery {
        require(
            msg.sender == lottery,
            "KingsCastle: caller is not the lottery"
        );
        _;
    }

    constructor(
        address _owner,
        uint256 _rewardRate,
        uint256 _maxClaims,
        uint256 _maxAmountOfStakers
    )
    {
        transferOwnership(_owner);
        rewardRate = _rewardRate;
        maxClaims = _maxClaims;
        maxAmountOfStakers = _maxAmountOfStakers;
    }
    
    receive() external payable {}
    
    function setLottery(address _lottery) external onlyOwner {
        lottery = _lottery;
    }
    
    function addWinningToken(uint256 _tokenId) external onlyLottery {
        winningTokens.add(_tokenId);
    }
    
    function stake(uint256 _tokenId) external {
        require(
            msg.sender == IERC721(lottery).ownerOf(_tokenId),
            "KingsCastle: caller is not the owner"
        );
        require(
            winningTokens.contains(_tokenId),
            "KingsCastle: not a winning token"
        );
        if (!stakers.contains(msg.sender)) {
            stakers.add(msg.sender);
            require(
                stakers.length() <= maxAmountOfStakers,
                "KingsCastle: max amount of stakers has been reached"
            );
        }
        IERC721(lottery).transferFrom(
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
        amountOfStakedTokens++;
        emit Stake(msg.sender, _tokenId);
    }
    
    function updateRewardRate(uint256 _rewardRate) external onlyOwner {
        require(
            _rewardRate > 0,
            "KingsCastle: invalid reward rate"
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
    
    function claim() public nonReentrant {
        require(
            stakers.contains(msg.sender),
            "KingsCastle: forbidden to claim"
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
                ILottery(lottery).burn(tokenId);
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
        return userInfo[__account].tokens.length();
    }

    function tokenOfOwnerByIndex(
        address _account,
        uint256 _index
    )
        public
        view
        returns (uint256)
    {
        return userInfo[_account].tokens.at(_index);
    }

    function safeRewardTransfer(address _to, uint256 _amount) internal returns (uint256) {
        uint256 balance = address(this).balance;
        if (balance >= _amount) {
            Address.sendValue(payable(_to), _amount);
            return _amount;
        }
        if (balance > 0) {
            Address.sendValue(payable(_to), balance);
        }
        emit InsufficientReward(_to, _amount, balance);
        return balance;
    }
}
