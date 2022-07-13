//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./base/ERC721.sol";
import "./interfaces/IKingsCastle.sol";

contract Lottery is ERC721, VRFConsumerBase, Ownable {
    enum State { OPEN, CLOSED, FAILED }
    
    uint256 public constant PRICE = 0.015 ether;
    uint256 public constant AMOUNT_OF_TOKENS_PER_LOTTERY = 500;
    uint256 public constant LOTTERY_DURATION = 180 days;
    
    uint256 public maxSupply = 500;
    uint256 public currentSupply;
    uint256 public lotteryEndTime;
    uint256 public nonce;
    uint256 private previousSupply;
    uint256 private chainlinkFee;
    address public kingsCastle;
    address public seaOfRedemption;
    address public devWallet;
    string private BASE_URI;
    bytes32 private keyHash;
    
    mapping(address => mapping(uint256 => uint256[])) public tokensOfUserPerLottery;
    mapping(address => mapping(uint256 => bool)) public withdrawals;
    mapping(uint256 => State) public statePerLottery;

    event RandomnessRequested(bytes32 requestId);
    
    constructor(
        address _VRFCoordinator,
        address _LINK,
        address _kingsCastle,
        address _seaOfRedemption,
        address _devWallet,
        bytes32 _keyHash,
        uint256 _chainlinkFee,
        string memory _name,
        string memory _symbol
    )
        VRFConsumerBase(_VRFCoordinator, _LINK)
        ERC721(_name, _symbol, _kingsCastle, _seaOfRedemption)
    {
        kingsCastle = _kingsCastle;
        seaOfRedemption = _seaOfRedemption;
        devWallet = _devWallet;
        keyHash = _keyHash;
        chainlinkFee = _chainlinkFee;
        statePerLottery[nonce] = State.OPEN;
        lotteryEndTime = block.timestamp + LOTTERY_DURATION;
    }

    receive() external payable onlyOwner {}

    function buy(uint256 _amount) external payable {
        require(
            statePerLottery[nonce] == State.OPEN,
            "lottery closed or failed"
        );
        require(
            _amount > 0 &&
            _amount <= AMOUNT_OF_TOKENS_PER_LOTTERY,
            "invalid amount"
        );
        require(
            msg.value == _amount * PRICE,
            "invalid msg.value"
        );
        require(
            currentSupply + _amount <= maxSupply,
            "max supply exceeded"
        );
        require(
            LINK.balanceOf(address(this)) >= chainlinkFee,
            "not enough LINK"
        );
        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(msg.sender, currentSupply);
            tokensOfUserPerLottery[msg.sender][nonce].push(currentSupply);
            currentSupply++;
        }
        if (currentSupply == maxSupply) {
            bytes32 requestId = requestRandomness(keyHash, chainlinkFee);
            emit RandomnessRequested(requestId);
        }
    }
    
    function withdrawEther(uint256 _nonce) external {
        require(
            statePerLottery[_nonce] == State.FAILED,
            "allowed to withdraw only when lottery failed"
        );
        require(
            withdrawals[msg.sender][_nonce] == false,
            "re-attempt to withdrawal"
        );
        uint256 amount = tokensOfUserPerLottery[msg.sender][_nonce].length * PRICE;
        payable(msg.sender).transfer(amount);
        withdrawals[msg.sender][_nonce] = true;
    }

    function setBaseURI(string memory _uri) external onlyOwner {
        BASE_URI = _uri;
    }
    
    function declareLotteryFailed() external onlyOwner {
        require(
            block.timestamp >= lotteryEndTime,
            "it is too early to declare the lottery failed"
        );
        require(
            statePerLottery[nonce] == State.OPEN,
            "only an open lottery can be declared failed"
        );
        statePerLottery[nonce] = State.FAILED;
        previousSupply = currentSupply;
    }
    
    function startNewLottery() external onlyOwner {
        require(
            statePerLottery[nonce] == State.CLOSED ||
            statePerLottery[nonce] == State.FAILED,
            "cannot start a new lottery until the current one is open"
        );
        maxSupply = currentSupply + AMOUNT_OF_TOKENS_PER_LOTTERY;
        nonce++;
        statePerLottery[nonce] = State.OPEN;
        lotteryEndTime = block.timestamp + LOTTERY_DURATION;
    }
    
    function fulfillRandomness(
        bytes32,
        uint256 _randomness
    )
        internal
        override
    {
        uint256 winningTokenId = _randomness % AMOUNT_OF_TOKENS_PER_LOTTERY + previousSupply;
        address winner = ownerOf(winningTokenId);
        _distributeTokens(winner);
        IKingsCastle(kingsCastle).addTicket(winningTokenId);
        previousSupply = currentSupply;
        statePerLottery[nonce] = State.CLOSED;
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
