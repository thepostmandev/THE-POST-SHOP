//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./base/ERC721.sol";

contract Lottery is ERC721, Ownable, VRFConsumerBase {
  
    uint256 public constant PRICE = 0.015 ether;
    
    uint256 public maxSupply;
    uint256 public currentSupply;
    uint256 private chainlinkFee;
    address public kingsCastle;
    address public seaOfRedemption;
    address public devWallet;
    string private BASE_URI;
    bytes32 private keyHash;
    
    event RandomnessRequested(bytes32 requestId);
    
    constructor(
        address _VRFCoordinator,
        address _LINK,
        address _kingsCastle,
        address _seaOfRedemption,
        address _devWallet,
        uint256 _chainlinkFee,
        uint256 _maxSupply,
        bytes32 _keyHash
    )
        VRFConsumerBase(_VRFCoordinator, _LINK)
        ERC721("Mini Chad Tier 1", "MCT1")
    {
        kingsCastle = _kingsCastle;
        seaOfRedemption = _seaOfRedemption;
        devWallet = _devWallet;
        chainlinkFee = _chainlinkFee;
        maxSupply = _maxSupply;
        keyHash = _keyHash;
    }

    receive() external payable onlyOwner {}

    function buyTickets(uint256 _amount) external payable {
        require(
            _amount > 0 &&
            _amount <= maxSupply,
            "invalid amount"
        );
        require(
            msg.value == _amount * PRICE,
            "invalid msg.value"
        );
        require(
            currentSupply + _amount <= maxSupply,
            "total supply exceeded"
        );
        require(
            LINK.balanceOf(address(this)) >= chainlinkFee,
            "not enough LINK"
        );
        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(msg.sender, currentSupply);
            currentSupply++;
        }
        if (currentSupply == maxSupply) {
            bytes32 requestId = requestRandomness(keyHash, chainlinkFee);
            emit RandomnessRequested(requestId);
        }
    }

    function setBaseURI(string memory _uri) external onlyOwner {
        BASE_URI = _uri;
    }
    
    function finishLotteryUrgently() external onlyOwner {
        bytes32 requestId = requestRandomness(keyHash, chainlinkFee);
        emit RandomnessRequested(requestId);
    }
    
    function fulfillRandomness(
        bytes32,
        uint256 _randomness
    )
        internal
        override
    {
        uint256 winningTokenId = _randomness % currentSupply;
        address winner = ownerOf(winningTokenId);
        _distributeTokens(winner);
    }
    
    function _baseURI() internal view override returns (string memory) {
        return BASE_URI;
    }

    function _distributeTokens(address _winner) private {
        payable(kingsCastle).transfer(1 ether);
        payable(seaOfRedemption).transfer(4 ether);
        payable(devWallet).transfer(1 ether);
        payable(_winner).transfer(1.5 ether);
    }
}
