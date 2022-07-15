const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");
ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);

const callBackWithRandomness = async(receipt) => {
    for (let i = 0; i < receipt.events.length; i++) {
        if (receipt.events[i].event == "RandomnessRequested") {
            const requestId = receipt.events[i].args.requestId;
            await vrfCoordinatorMock.callBackWithRandomness(requestId, 10, lottery.address);
        }
    }
}

const increaseTime = async(time) => {
    await ethers.provider.send("evm_increaseTime", [time]);
    await ethers.provider.send("evm_mine");
}

describe("Lottery", function() {
    beforeEach(async function() {
        [owner, alice, devWallet] = await ethers.getSigners();
        const LinkToken = await ethers.getContractFactory("LinkToken");
        linkToken = await LinkToken.deploy();
        const VRFCoordinatorMock = await ethers.getContractFactory("VRFCoordinatorMock");
        vrfCoordinatorMock = await VRFCoordinatorMock.deploy(linkToken.address);
        const KingsCastleFactory = await ethers.getContractFactory("KingsCastleFactory");
        kingsCastleFactory = await KingsCastleFactory.deploy();
        await kingsCastleFactory.createKingsCastle(BigNumber.from("115740740741"), 10, 10); // 0.01 ETH/DAY
        const kingsCastleAddress = await kingsCastleFactory.getKingsCastleAt(0);
        const SeaOfRedemptionFactory = await ethers.getContractFactory("SeaOfRedemptionFactory");
        seaOfRedemptionFactory = await SeaOfRedemptionFactory.deploy();
        await seaOfRedemptionFactory.createSeaOfRedemption(BigNumber.from("115740740741"), 10, 10); // 0.01 ETH/DAY
        const seaOfRedemptionAddress = await seaOfRedemptionFactory.getSeaOfRedemptionAt(0);
        kingsCastle = await ethers.getContractAt("KingsCastle", kingsCastleAddress);
        seaOfRedemption = await ethers.getContractAt("SeaOfRedemption", seaOfRedemptionAddress);
        distribution = [
            ethers.utils.parseEther("0.1"),
            ethers.utils.parseEther("0.4"),
            ethers.utils.parseEther("0.1"),
            ethers.utils.parseEther("0.15")
        ];
        const LotteryFactory = await ethers.getContractFactory("LotteryFactory");
        lotteryFactory = await LotteryFactory.deploy();
        await lotteryFactory.createLottery(
            vrfCoordinatorMock.address,
            linkToken.address,
            kingsCastle.address,
            seaOfRedemption.address,
            devWallet.address,
            ethers.utils.parseEther("0.015"),
            50,
            distribution,
            "Mini Chad - Tier 1",
            "MCT1"
        );
        const lotteryAddress = await lotteryFactory.getLotteryAt(0);
        lottery = await ethers.getContractAt("Lottery", lotteryAddress);
        await kingsCastle.setLottery(lottery.address);
        await seaOfRedemption.setLottery(lottery.address);
    });
    
    it("Successful buyTickets() execution", async() => {
        await expect(lottery.buyTickets(0, {value: ethers.utils.parseEther("0.15")})).to.be.revertedWith("invalid amount");
        await expect(lottery.buyTickets(2, {value: ethers.utils.parseEther("0.15")})).to.be.revertedWith("invalid msg.value");
        await expect(lottery.buyTickets(1, {value: ethers.utils.parseEther("0.015")})).to.be.revertedWith("not enough LINK");
        await linkToken.transfer(lottery.address, ethers.utils.parseEther("10"));
        await lottery.buyTickets(1, {value: ethers.utils.parseEther("0.015")});
        await expect(lottery.buyTickets(50, {value: ethers.utils.parseEther("0.75")})).to.be.revertedWith("max supply exceeded");
        tx = await lottery.connect(alice).buyTickets(49, {value: ethers.utils.parseEther("0.735")});
        receipt = await tx.wait();
        balanceBefore = await ethers.provider.getBalance(alice.address);
        await callBackWithRandomness(receipt);
        balanceAfter = await ethers.provider.getBalance(alice.address);
        const winner = await lottery.winnerPerLottery(0);
        expect(winner).to.equal(alice.address);
        expect(await ethers.provider.getBalance(kingsCastle.address)).to.equal(ethers.utils.parseEther("0.1"));
        expect(await ethers.provider.getBalance(seaOfRedemption.address)).to.equal(ethers.utils.parseEther("0.4"));
        expect((await ethers.provider.getBalance(devWallet.address)).sub(ethers.utils.parseEther("10000"))).to.equal(ethers.utils.parseEther("0.1"));
        expect(balanceAfter.sub(balanceBefore)).to.equal(ethers.utils.parseEther("0.15"));
    });
    
    it("Successful withdrawFunds() and declareLotteryFailed() execution", async() => {
        await linkToken.transfer(lottery.address, ethers.utils.parseEther("10"));
        await lottery.buyTickets(1, {value: ethers.utils.parseEther("0.015")});
        await expect(lottery.withdrawFunds(0)).to.be.revertedWith("allowed to withdraw only when lottery failed");
        await expect(lottery.declareLotteryFailed()).to.be.revertedWith("it is too early to declare the lottery failed");
        await increaseTime(15552000);
        await lottery.declareLotteryFailed();
        await lottery.withdrawFunds(0);
        await expect(lottery.connect(alice).withdrawFunds(0)).to.be.revertedWith("sender did not buy tokens on this lottery");
        await expect(lottery.withdrawFunds(0)).to.be.revertedWith("re-attempt to withdrawal");
    });
    
    it("Successful tokenURI() execution", async() => {
        await linkToken.transfer(lottery.address, ethers.utils.parseEther("10"));
        await lottery.buyTickets(1, {value: ethers.utils.parseEther("0.015")});
        await lottery.setBaseURI("test");
        await lottery.tokenURI(0);
    });
    
    it("Successful getWinningToken() execution", async() => {
        await linkToken.transfer(lottery.address, ethers.utils.parseEther("10"));
        await expect(lottery.getWinningToken(0)).to.be.revertedWith("empty set");
        tx = await lottery.buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await expect(lottery.getWinningToken(1)).to.be.revertedWith("invalid index");
        await lottery.getWinningToken(0);
    });
});
