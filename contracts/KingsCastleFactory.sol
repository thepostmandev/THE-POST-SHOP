//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./KingsCastle.sol";

contract KingsCastleFactory is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    EnumerableSet.AddressSet kingsCastles;
    
    event KingsCastleCreated(
        address kingsCastleAddress,
        address owner,
        uint256 rewardRate,
        uint256 maxClaims,
        uint256 maxAmountOfStakers
    );
    
    function createKingsCastle(
        uint256 _rewardRate,
        uint256 _maxClaims,
        uint256 _maxAmountOfStakers
    )
        external
        onlyOwner
    {
        KingsCastle kingsCastle = new KingsCastle(
            owner(),
            _rewardRate,
            _maxClaims,
            _maxAmountOfStakers
        );
        kingsCastles.add(address(kingsCastle));
        emit KingsCastleCreated(
            address(kingsCastle),
            owner(),
            _rewardRate,
            _maxClaims,
            _maxAmountOfStakers
        );
    }
    
    function removeKingsCastle(address _kingsCastle) external onlyOwner {
        require(
            kingsCastles.contains(_kingsCastle),
            "kings castle not found"
        );
        kingsCastles.remove(_kingsCastle);
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
    
    function amountOfKingsCastles() external view returns (uint256) {
        return kingsCastles.length();
    }
}
