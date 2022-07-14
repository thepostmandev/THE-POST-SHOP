//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./base/ERC721.sol";
import "./interfaces/IKingsCastle.sol";
import "./interfaces/ILottery.sol";
import "hardhat/console.sol";

contract Lottery is ERC721, VRFConsumerBase, Ownable, ILottery {
    using EnumerableSet for EnumerableSet.UintSet;
    
    enum State { OPEN, FAILED }
    
    uint256 public constant LOTTERY_DURATION = 180 days;
    uint256 private constant CHAINLINK_FEE = 2 ether;
    bytes32 private constant KEY_HASH = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
    
    uint256 public maxSupply;
    uint256 public currentSupply;
    uint256 public lotteryEndTime;
    uint256 public price;
    uint256 public amountOfTokensPerLottery;
    uint256 public nonce;
    uint256 private previousSupply;
    address public kingsCastle;
    address public seaOfRedemption;
    address public devWallet;
    string private BASE_URI;
    Distribution private distribution;
    
    mapping(address => mapping(uint256 => uint256[])) public tokensOfUserPerLottery;
    mapping(address => mapping(uint256 => bool)) public withdrawals;
    mapping(uint256 => State) public statePerLottery;
    mapping(uint256 => address) public winnersPerLottery;
    EnumerableSet.UintSet private winningTokens;
    
    event RandomnessRequested(bytes32 requestId);
    
    constructor(
        address _owner,
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
        VRFConsumerBase(_VRFCoordinator, _LINK)
        ERC721(_name, _symbol, _kingsCastle, _seaOfRedemption)
        Ownable()
    {
        transferOwnership(_owner);
        kingsCastle = _kingsCastle;
        seaOfRedemption = _seaOfRedemption;
        devWallet = _devWallet;
        price = _price;
        amountOfTokensPerLottery = _amountOfTokensPerLottery;
        maxSupply = _amountOfTokensPerLottery;
        distribution = _distribution;
        statePerLottery[nonce] = State.OPEN;
        lotteryEndTime = block.timestamp + LOTTERY_DURATION;
    }

    receive() external payable onlyOwner {}

    function buyTickets(uint256 _amount) external payable {
        require(
            _amount > 0 &&
            _amount <= amountOfTokensPerLottery,
            "invalid amount"
        );
        require(
            msg.value == _amount * price,
            "invalid msg.value"
        );
        require(
            currentSupply + _amount <= maxSupply,
            "max supply exceeded"
        );
        require(
            LINK.balanceOf(address(this)) >= CHAINLINK_FEE,
            "not enough LINK"
        );
        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(msg.sender, currentSupply);
            tokensOfUserPerLottery[msg.sender][nonce].push(currentSupply);
            currentSupply++;
        }
        if (currentSupply == maxSupply) {
            bytes32 requestId = requestRandomness(KEY_HASH, CHAINLINK_FEE);
            emit RandomnessRequested(requestId);
        }
    }
    
    function withdrawFunds(uint256 _nonce) external {
        require(
            statePerLottery[_nonce] == State.FAILED,
            "allowed to withdraw only when lottery failed"
        );
        require(
            withdrawals[msg.sender][_nonce] == false,
            "re-attempt to withdrawal"
        );
        uint256 amount = tokensOfUserPerLottery[msg.sender][_nonce].length * price;
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
        statePerLottery[nonce] = State.FAILED;
        startNewLottery();
    }
    
    function getWinningToken(uint256 _index) external view returns (uint256) {
        require(
            winningTokens.length() > 0,
            "empty set"
        );
        require(
            _index < winningTokens.length(),
            "invalid index"
        );
        return winningTokens.at(_index);
    }
    
    function fulfillRandomness(
        bytes32,
        uint256 _randomness
    )
        internal
        override
    {
        uint256 winningToken = _randomness % amountOfTokensPerLottery + previousSupply;
        winningTokens.add(winningToken);
        address winner = ownerOf(winningToken);
        winnersPerLottery[nonce] = winner;
        _distribute(winner);
        IKingsCastle(kingsCastle).addWinningToken(winningToken);
        startNewLottery();
    }
    
    function _baseURI() internal view override returns (string memory) {
        return BASE_URI;
    }
    
    function startNewLottery() private {
        previousSupply = currentSupply;
        maxSupply = currentSupply + amountOfTokensPerLottery;
        nonce++;
        statePerLottery[nonce] = State.OPEN;
        lotteryEndTime = block.timestamp + LOTTERY_DURATION;
    }

    function _distribute(address _winner) private {
        payable(kingsCastle).transfer(distribution.toKingsCastle);
        payable(seaOfRedemption).transfer(distribution.toSeaOfRedemption);
        payable(devWallet).transfer(distribution.toDevWallet);
        payable(_winner).transfer(distribution.toWinner);
    }
}
