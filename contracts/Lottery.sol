//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./base/ERC721.sol";
import "./interfaces/IKingsCastle.sol";

contract Lottery is ERC721, Ownable, VRFConsumerBase {
    enum State {
        OPEN,
        CLOSED,
        FAILED
    }
  
    uint256 public constant PRICE = 0.015 ether;
    
    uint256 public totalSupply;
    uint256 public currentSupply;
    uint256 public amountOfTokensPerLottery;
    uint256 public infimum;
    uint256 private chainlinkFee;
    address public kingsCastle;
    address public seaOfRedemption;
    address public devWallet;
    string private BASE_URI;
    bytes32 private keyHash;
    State public state;
    
    event RandomnessRequested(bytes32 requestId);
    
    constructor(
        address _VRFCoordinator,
        address _LINK,
        address _kingsCastle,
        address _seaOfRedemption,
        address _devWallet,
        uint256 _chainlinkFee,
        uint256 _totalSupply,
        uint256 _amountOfTokensPerLottery,
        bytes32 _keyHash,
        string memory _name,
        string memory _symbol
    )
        VRFConsumerBase(_VRFCoordinator, _LINK)
        ERC721(_name, _symbol, _kingsCastle, _seaOfRedemption)
    {
        kingsCastle = _kingsCastle;
        seaOfRedemption = _seaOfRedemption;
        devWallet = _devWallet;
        chainlinkFee = _chainlinkFee;
        totalSupply = _totalSupply;
        amountOfTokensPerLottery = _amountOfTokensPerLottery;
        keyHash = _keyHash;
    }

    receive() external payable onlyOwner {}

    function buyTickets(uint256 _amount) external payable {
        require(
            state == State.OPEN,
            "lottery closed or failed"
        );
        require(
            _amount > 0 &&
            _amount <= totalSupply,
            "invalid amount"
        );
        require(
            msg.value == _amount * PRICE,
            "invalid msg.value"
        );
        require(
            currentSupply + _amount <= totalSupply,
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
        if (currentSupply == totalSupply) {
            bytes32 requestId = requestRandomness(keyHash, chainlinkFee);
            emit RandomnessRequested(requestId);
        }
    }
    
    function withdrawEther() external {
        require(
            state == State.FAILED,
            "allowed to withdraw only when lottery failed"
        );
        uint256 amount = balanceOf(msg.sender) * PRICE;
        payable(msg.sender).transfer(amount);
    }

    function setBaseURI(string memory _uri) external onlyOwner {
        BASE_URI = _uri;
    }
    
    function changeLotteryState(State _state) external onlyOwner {
        state = _state;
    }
    
    function updateTotalSupply() external onlyOwner {
        totalSupply += amountOfTokensPerLottery;
    }
    
    function fulfillRandomness(
        bytes32,
        uint256 _randomness
    )
        internal
        override
    {
        uint256 winningTokenId = _randomness % amountOfTokensPerLottery + infimum;
        address winner = ownerOf(winningTokenId);
        _distributeTokens(winner);
        IKingsCastle(kingsCastle).addTicket(winningTokenId);
        infimum = totalSupply;
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
