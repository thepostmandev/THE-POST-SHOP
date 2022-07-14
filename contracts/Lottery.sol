//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./base/ERC721.sol";
import "./interfaces/IKingsCastle.sol";
import "./interfaces/ILottery.sol";

contract Lottery is ERC721, VRFConsumerBase, Ownable, ILottery {
    enum State { OPEN, CLOSED, FAILED }
    
    uint256 public constant LOTTERY_DURATION = 180 days;
    /* WARNING: don't forget to change it in MAINNET */
    uint256 private constant CHAINLINK_FEE = 0.1 ether;
    bytes32 private constant KEY_HASH = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
    
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

    event RandomnessRequested(bytes32 requestId);
    
    constructor(
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
    {
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
            statePerLottery[nonce] == State.OPEN,
            "lottery closed or failed"
        );
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
        maxSupply = currentSupply + amountOfTokensPerLottery;
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
        uint256 winningTokenId = _randomness % amountOfTokensPerLottery + previousSupply;
        address winner = ownerOf(winningTokenId);
        _distribute(winner);
        IKingsCastle(kingsCastle).addWinningToken(winningTokenId);
        previousSupply = currentSupply;
        statePerLottery[nonce] = State.CLOSED;
    }
    
    function _baseURI() internal view override returns (string memory) {
        return BASE_URI;
    }

    function _distribute(address _winner) private {
        payable(kingsCastle).transfer(distribution.toKingsCastle);
        payable(seaOfRedemption).transfer(distribution.toSeaOfRedemption);
        payable(devWallet).transfer(distribution.toDevWallet);
        payable(_winner).transfer(distribution.toWinner);
    }
}
