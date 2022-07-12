//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

contract KingsCastle is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    
    struct UserInfo {
        EnumerableSet.UintSet tickets;
        mapping(uint256 => uint256) avaibleClaimsPerToken;
        uint256 rewards;
        uint256 lastRewardBlock;
    }

    IERC721 public lottery;
    uint256 public rewardPerBlock = 0.000001 ether;
    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public maxClaims;
    
    EnumerableSet.UintSet winningTickets;
    mapping(address => UserInfo) private userInfo;

    event RewardPerBlockUpdated(uint256 oldValue, uint256 newValue);
    event Staked(address indexed account, uint256 tokenId);
    event Withdrawn(address indexed account, uint256 tokenId);
    event Harvested(address indexed account, uint256 amount);
    event InsufficientRewardToken(address indexed account, uint256 amountNeeded, uint256 balance);
    
    modifier onlyLottery() {
        require(
            _msgSender() == address(lottery),
            "only lottery can call this function"
        );
        _;
    }

    constructor(
        IERC721 _lottery,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _maxClaims
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
        maxClaims = _maxClaims;
    }
    
    function stake(uint256 _tokenId) external nonReentrant {
        require(
            winningTickets.contains(_tokenId),
            "not a winning ticket"
        );
        claim();
        IERC721(lottery).safeTransferFrom(
            _msgSender(),
            address(this),
            _tokenId
        );
        UserInfo storage user = userInfo[_msgSender()];
        user.tickets.add(_tokenId);
        user.avaibleClaimsPerToken[_tokenId] = maxClaims;
        emit Staked(_msgSender(), _tokenId);
    }
    
    function addTicket(uint256 _tokenId) external onlyLottery {
        winningTickets.add(_tokenId);
    }
    
    function claim() public nonReentrant {
        UserInfo storage user = userInfo[_msgSender()];
        uint256 pendingAmount = pendingRewards(_msgSender());
        for (uint256 i = 0; i < user.tickets.length(); i++) {
            uint256 tokenId = user.tickets.at(i);
            uint256 avaibleClaims = user.avaibleClaimsPerToken[tokenId]--;
            if (avaibleClaims == 0) {
                user.tickets.remove(tokenId);
                winningTickets.remove(tokenId);
            }
        }
        if (pendingAmount > 0) {
            uint256 amountSent = safeRewardTransfer(_msgSender(), pendingAmount);
            user.rewards = pendingAmount - amountSent;
            user.lastRewardBlock = block.number;
            emit Harvested(_msgSender(), amountSent);
        }
    }
    
    function updateRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        require(_rewardPerBlock > 0, "Invalid reward per block");
        emit RewardPerBlockUpdated(rewardPerBlock, _rewardPerBlock);
        rewardPerBlock = _rewardPerBlock;
    }

    function updateStartBlock(uint256 _startBlock) external onlyOwner {
        require(
            _startBlock <= endBlock,
            "Start block must be before end block"
        );
        require(_startBlock > block.number, "Start block must be after current block");
        require(startBlock > block.number, "Staking started already");
        startBlock = _startBlock;
    }

    function updateEndBlock(uint256 _endBlock) external onlyOwner {
        require(
            _endBlock >= startBlock,
            "End block must be after start block"
        );
        require(
            _endBlock > block.number,
            "End block must be after current block"
        );
        endBlock = _endBlock;
    }
    
    function updateMaxClaims(uint256 _maxClaims) external onlyOwner {
        maxClaims = _maxClaims;
    }

    function viewUserInfo(
        address __account
    )
        external
        view
        returns (
            uint256[] memory tickets,
            uint256 rewards,
            uint256 lastRewardBlock
        )
    {
        UserInfo storage user = userInfo[__account];
        rewards = user.rewards;
        lastRewardBlock = user.lastRewardBlock;
        uint256 countNfts = user.tickets.length();
        if (countNfts == 0) {
            tickets = new uint256[](0);
        } else {
            tickets = new uint256[](countNfts);
            uint256 index;
            for (index = 0; index < countNfts; index++) {
                tickets[index] = tokenOfOwnerByIndex(__account, index);
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
        return user.tickets.at(__index);
    }

    function userStakedNFTCount(
        address __account
    )
        public
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[__account];
        return user.tickets.length();
    }

    function isStaked(
        address __account,
        uint256 __tokenId
    )
        public
        view
        returns (bool)
    {
        UserInfo storage user = userInfo[__account];
        return user.tickets.contains(__tokenId);
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
