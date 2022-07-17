//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./SeaOfRedemption.sol";

contract SeaOfRedemptionFactory is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    EnumerableSet.AddressSet private seasOfRedemption;
    
    event SeaOfRedemptionCreated(
        address seaOfRedemptionAddress,
        address owner,
        uint256 rewardRate,
        uint256 maxClaims,
        uint256 maxAmountOfStakers
    );
    
    function createSeaOfRedemption(
        uint256 _rewardRate,
        uint256 _maxClaims,
        uint256 _maxAmountOfStakers
    )
        external
        onlyOwner
    {
        SeaOfRedemption seaOfRedemption = new SeaOfRedemption(
            owner(),
            _rewardRate,
            _maxClaims,
            _maxAmountOfStakers
        );
        seasOfRedemption.add(address(seaOfRedemption));
        emit SeaOfRedemptionCreated(
            address(seaOfRedemption),
            owner(),
            _rewardRate,
            _maxClaims,
            _maxAmountOfStakers
        );
    }
    
    function removeSeaOfRedemption(address _seaOfRedemption) external onlyOwner {
        seasOfRedemption.remove(_seaOfRedemption);
    }
    
    function getSeaOfRedemptionAt(uint256 _index) external view returns (address) {
        return seasOfRedemption.at(_index);
    }
    
    function amountOfSeasOfRedemption() external view returns (uint256) {
        return seasOfRedemption.length();
    }
}
