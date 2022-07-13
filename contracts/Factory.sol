//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./KingsCastle.sol";
import "./Lottery.sol";

contract Factory is Ownable {
    address[] public kingsCastles;
    address[] public lotteries;
    
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
    
    function amountOfKingsCastles() external view returns (uint256) {
        return kingsCastles.length;
    }
    
    function amountOfLotteries() external view returns (uint256) {
        return lotteries.length;
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
        kingsCastles.push(address(kingsCastle));
        emit KingsCastleCreated(
          address(kingsCastle)
          _rewardPerBlock,
          _startBlock,
          _endBlock,
          _maxClaims,
          _maxAmountOfStakers
        )
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
        lotteries.push(address(lottery));
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
        )
    }
}
