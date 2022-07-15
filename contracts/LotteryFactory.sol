//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ILottery.sol";
import "./Lottery.sol";

contract LotteryFactory is Ownable, ILottery {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    EnumerableSet.AddressSet lotteries;
    
    event LotteryCreated(
        address lotteryAddress,
        address owner,
        address kingsCastle,
        address seaOfRedemption,
        address devWallet,
        uint256 price,
        uint256 amountOfTokensPerLottery,
        Distribution distribution,
        string name,
        string symbol
    );
    
    function createLottery(
        address _VRFCoordinator,
        address _LINK,
        address _kingsCastle,
        address _seaOfRedemption,
        address _devWallet,
        uint256 _price,
        uint256 _amountOfTokensPerLottery,
        Distribution memory _distribution,
        string memory _name,
        string memory _symbol
    )
        external
        onlyOwner
    {
        Lottery lottery = new Lottery(
            owner(),
            _VRFCoordinator,
            _LINK,
            _kingsCastle,
            _seaOfRedemption,
            _devWallet,
            _price,
            _amountOfTokensPerLottery,
            _distribution,
            _name,
            _symbol
        );
        lotteries.add(address(lottery));
        emit LotteryCreated(
            address(lottery),
            owner(),
            _kingsCastle,
            _seaOfRedemption,
            _devWallet,
            _price,
            _amountOfTokensPerLottery,
            _distribution,
            _name,
            _symbol
        );
    }
    
    function removeLottery(address _lottery) external onlyOwner {
        require(
            lotteries.contains(_lottery),
            "lottery not found"
        );
        lotteries.remove(_lottery);
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

    function amountOfLotteries() external view returns (uint256) {
        return lotteries.length();
    }
}
