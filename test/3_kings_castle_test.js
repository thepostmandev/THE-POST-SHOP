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

describe("KingsCastle", function() {
    beforeEach(async function() {
        [owner, alice, bob, seaOfRedemption, devWallet] = await ethers.getSigners();
        const LinkToken = await ethers.getContractFactory("LinkToken");
        linkToken = await LinkToken.deploy();
        const VRFCoordinatorMock = await ethers.getContractFactory("VRFCoordinatorMock");
        vrfCoordinatorMock = await VRFCoordinatorMock.deploy(linkToken.address);
        const Factory = await ethers.getContractFactory("Factory");
        factory = await Factory.deploy();
        await factory.createKingsCastle(BigNumber.from("115740740740"), 10, 2); // 0.01 ETH/DAY
        const kingsCastleAddress = await factory.getKingsCastleAt(0);
        kingsCastle = await ethers.getContractAt("KingsCastle", kingsCastleAddress);
        distribution = [
            ethers.utils.parseEther("0.1"),
            ethers.utils.parseEther("0.4"),
            ethers.utils.parseEther("0.1"),
            ethers.utils.parseEther("0.15")
        ];
        await factory.createLottery(
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
        const lotteryAddress = await factory.getLotteryAt(0);
        lottery = await ethers.getContractAt("Lottery", lotteryAddress);
        await kingsCastle.setLottery(lottery.address);
        await linkToken.transfer(lottery.address, ethers.utils.parseEther("10"));
    });
    
    it("Successful stake() execution", async() => {
        await lottery.connect(alice).buyTickets(1, {value: ethers.utils.parseEther("0.015")})
        tx = await lottery.buyTickets(49, {value: ethers.utils.parseEther("0.735")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await expect(kingsCastle.stake(0)).to.be.revertedWith("sender is not the owner");
        await expect(kingsCastle.connect(alice).stake(0)).to.be.revertedWith("not a winning ticket");
        await lottery.approve(kingsCastle.address, 10);
        await kingsCastle.stake(10);
        tx = await lottery.connect(alice).buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.connect(alice).approve(kingsCastle.address, 60);
        await kingsCastle.connect(alice).stake(60);
        tx = await lottery.buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.approve(kingsCastle.address, 110);
        await kingsCastle.stake(110);
        tx = await lottery.connect(bob).buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.connect(bob).approve(kingsCastle.address, 160);
        await expect(kingsCastle.connect(bob).stake(160)).to.be.revertedWith("max amount of stakers has been reached");
    });
    
    it("Successful claim() execution", async() => {
        tx = await lottery.buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        tx = await lottery.connect(alice).buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.approve(kingsCastle.address, 10);
        await kingsCastle.stake(10);
        await increaseTime(86399);
        await kingsCastle.claim();
        await expect(kingsCastle.connect(bob).claim()).to.be.revertedWith("forbidden to claim");
        await lottery.connect(alice).approve(kingsCastle.address, 60);
        await kingsCastle.connect(alice).stake(60);
        await increaseTime(86399);
        await kingsCastle.connect(alice).claim();
        for (let i = 0; i < 9; i++) {
            await kingsCastle.connect(alice).claim();
        }
        await expect(kingsCastle.connect(alice).claim()).to.be.revertedWith("forbidden to claim");
        await increaseTime(15552000);
        await kingsCastle.claim();
        await kingsCastle.claim();
    });
    
    it("Successful onlyLottery() check", async() => {
        await expect(kingsCastle.addWinningToken(10)).to.be.revertedWith("only lottery can call this function");
    });
    
    it("Successful updateRewardRate() execution", async() => {
        await expect(kingsCastle.updateRewardRate(0)).to.be.revertedWith("invalid reward rate");
        await kingsCastle.updateRewardRate(100);
    });
    
    it("Successful tokenOfOwnerByIndex() execution", async() => {
        await expect(kingsCastle.tokenOfOwnerByIndex(owner.address, 0)).to.be.reverted;
        tx = await lottery.buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.approve(kingsCastle.address, 10);
        await kingsCastle.stake(10);
        await kingsCastle.tokenOfOwnerByIndex(owner.address, 0);
    });
    
    it("Successful viewUserInfo() execution", async() => {
        await kingsCastle.viewUserInfo(owner.address);
        tx = await lottery.buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.approve(kingsCastle.address, 10);
        await kingsCastle.stake(10);
        await kingsCastle.viewUserInfo(owner.address);
    });
});
