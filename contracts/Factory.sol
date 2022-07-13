//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./KingsCastle.sol";
import "./Lottery.sol";

contract Factory is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    EnumerableSet.AddressSet kingsCastles;
    EnumerableSet.AddressSet lotteries;
    
    event KingsCastleCreated(
        address kingsCastleAddress,
        uint256 rewardPerBlock,
        uint256 startBlock,
        uint256 endBlock,
        uint256 maxClaims,
        uint256 maxAmountOfStakers
    );
    
    event LotteryCreated(
        address lotteryAddress,
        address kingsCastle,
        address seaOfRedemption,
        address devWallet,
        bytes32 keyHash,
        uint256 chainlinkFee,
        uint256 price,
        uint256 amountOfTokensPerLottery,
        string name,
        string symbol
    );
    
    
    function removeKingsCastle(address _kingsCastle) external onlyOwner {
        require(
            kingsCastles.contains(_kingsCastle),
            "kings castle not found"
        );
        kingsCastles.remove(_kingsCastle);
    }
    
    function removeLottery(address _lottery) external onlyOwner {
        require(
            lotteries.contains(_lottery),
            "lottery not found"
        );
        lotteries.remove(_lottery);
    }
    
    function createKingsCastle(
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _maxClaims,
        uint256 _maxAmountOfStakers
    )
        external
        onlyOwner
    {
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
        KingsCastle kingsCastle = new KingsCastle(
            _rewardPerBlock,
            _startBlock,
            _endBlock,
            _maxClaims,
            _maxAmountOfStakers
        );
        kingsCastles.add(address(kingsCastle));
        emit KingsCastleCreated(
            address(kingsCastle),
            _rewardPerBlock,
            _startBlock,
            _endBlock,
            _maxClaims,
            _maxAmountOfStakers
        );
    }
    
    function createLottery(
        address _VRFCoordinator,
        address _LINK,
        address _kingsCastle,
        address _seaOfRedemption,
        address _devWallet,
        bytes32 _keyHash,
        uint256 _chainlinkFee,
        uint256 _price,
        uint256 _amountOfTokensPerLottery,
        string memory _name,
        string memory _symbol
    )
        external
        onlyOwner
    {
        Lottery lottery = new Lottery(
            _VRFCoordinator,
            _LINK,
            _kingsCastle,
            _seaOfRedemption,
            _devWallet,
            _keyHash,
            _chainlinkFee,
            _price,
            _amountOfTokensPerLottery,
            _name,
            _symbol
        );
        lotteries.add(address(lottery));
        emit LotteryCreated(
            address(lottery),
            _kingsCastle,
            _seaOfRedemption,
            _devWallet,
            _keyHash,
            _chainlinkFee,
            _price,
            _amountOfTokensPerLottery,
            _name,
            _symbol
        );
    }
    
    function getKingsCastleAt(uint256 _index) external view returns (address) {
        require(
            kingsCastles.length() > 0,
            "empty set"
        );
        require(
            _index < kingsCastles.length(),
            "invalid index"
        );
        return kingsCastles.at(_index);
    }
    
    function getLotteryAt(uint256 _index) external view returns (address) {
        require(
            lotteries.length() > 0,
            "empty set"
        );
        require(
            _index < lotteries.length(),
            "invalid index"
        );
        return lotteries.at(_index);
    }
    
    function amountOfKingsCastles() external view returns (uint256) {
        return kingsCastles.length();
    }
    
    function amountOfLotteries() external view returns (uint256) {
        return lotteries.length();
    }
}
