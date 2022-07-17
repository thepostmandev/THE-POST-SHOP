//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IDistribution {
    struct Distribution {
        uint256 toKingsCastle;
        uint256 toSeaOfRedemption;
        uint256 toDevWallet;
        uint256 toWinner;
    }
}
