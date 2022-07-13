//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

contract KingsCastle is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    
    struct UserInfo {
        EnumerableSet.UintSet tokens;
        mapping(uint256 => uint256) avaibleClaimsPerToken;
        uint256 rewards;
        uint256 lastRewardBlock;
    }
    
    uint256 constant public MAX_CLAIMS = 10;
    uint256 constant public MAX_AMOUNT_OF_DEPOSITORS = 10;

    IERC721 public lottery;
    uint256 public rewardPerBlock = 0.000001 ether;
    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public maxClaims;
    
    EnumerableSet.UintSet winningTokens;
    EnumerableSet.AddressSet depositors;
    mapping(address => UserInfo) private userInfo;

    event RewardPerBlockUpdated(uint256 oldValue, uint256 newValue);
    event Staked(address indexed account, uint256 tokenId);
    event Withdrawn(address indexed account, uint256 tokenId);
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
        IERC721 _lottery,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) {
        require(
            _rewardPerBlock > 0,
            "invalid reward per block"
        );
        require(
            _startBlock <= _endBlock,
            "start block must be before end block"
        );
        require(
            _startBlock > block.number,
            "start block must be after current block"
        );
        lottery = _lottery;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        endBlock = _endBlock;
    }
    
    function addWinningToken(uint256 _tokenId) external onlyLottery {
        winningTokens.add(_tokenId);
    }
    
    function stake(uint256 _tokenId) external nonReentrant {
        require(
            winningTokens.contains(_tokenId),
            "not a winning ticket"
        );
        require(
            depositors.length() <= MAX_AMOUNT_OF_DEPOSITORS,
            "max amount of depositors has been reached"
        );
        IERC721(lottery).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );
        if (!depositors.contains(msg.sender)) {
            depositors.add(msg.sender);
        }
        claim();
        UserInfo storage user = userInfo[msg.sender];
        user.tokens.add(_tokenId);
        user.avaibleClaimsPerToken[_tokenId] = MAX_CLAIMS;
        emit Staked(msg.sender, _tokenId);
    }
    
    function claim() external nonReentrant {
        require(
            depositors.contains(msg.sender),
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
            uint256 avaibleClaims = user.avaibleClaimsPerToken[tokenId]--;
            if (avaibleClaims == 0) {
                user.tokens.remove(tokenId);
                winningTokens.remove(tokenId);
            }
            if (user.tokens.length() == 0) {
                depositors.remove(msg.sender);
            }
        }
        user.lastRewardBlock = block.number;
    }
    
    function updateRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        require(_rewardPerBlock > 0, "invalid reward per block");
        emit RewardPerBlockUpdated(rewardPerBlock, _rewardPerBlock);
        rewardPerBlock = _rewardPerBlock;
    }

    function updateStartBlock(uint256 _startBlock) external onlyOwner {
        require(
            _startBlock <= endBlock,
            "start block must be before end block"
        );
        require(_startBlock > block.number, "start block must be after current block");
        require(startBlock > block.number, "staking started already");
        startBlock = _startBlock;
    }

    function updateEndBlock(uint256 _endBlock) external onlyOwner {
        require(
            _endBlock >= startBlock,
            "end block must be after start block"
        );
        require(
            _endBlock > block.number,
            "end block must be after current block"
        );
        endBlock = _endBlock;
    }

    function viewUserInfo(
        address __account
    )
        external
        view
        returns (
            uint256[] memory tokens,
            uint256 rewards,
            uint256 lastRewardBlock
        )
    {
        UserInfo storage user = userInfo[__account];
        rewards = user.rewards;
        lastRewardBlock = user.lastRewardBlock;
        uint256 countNfts = user.tokens.length();
        if (countNfts == 0) {
            tokens = new uint256[](0);
        } else {
            tokens = new uint256[](countNfts);
            uint256 index;
            for (index = 0; index < countNfts; index++) {
                tokens[index] = tokenOfOwnerByIndex(__account, index);
            }
        }
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

    function pendingRewards(address _account) public view returns (uint256) {
        UserInfo storage user = userInfo[_account];
        uint256 fromBlock = user.lastRewardBlock < startBlock ? startBlock : user.lastRewardBlock;
        uint256 toBlock = block.number < endBlock ? block.number : endBlock;
        if (toBlock < fromBlock) {
            return user.rewards;
        }
        uint256 amount = (toBlock - fromBlock) * userStakedNFTCount(_account) * rewardPerBlock;
        return user.rewards + amount;
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
