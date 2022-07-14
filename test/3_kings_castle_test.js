const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");
ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);

const callBackWithRandomness = async(receipt) => {
    for (let i = 0; i < receipt.events.length; i++) {
        if (receipt.events[i].event == "RandomnessRequested") {
            const requestId = receipt.events[i].args.requestId;
            await vrfCoordinatorMock.callBackWithRandomness(requestId, 100, lottery.address);
        }
    }
}

const increaseTime = async(time) => {
    await ethers.provider.send("evm_increaseTime", [time]);
    await ethers.provider.send("evm_mine");
}

describe("KingsCastle", function() {
    beforeEach(async function() {
        [owner, alice, seaOfRedemption, devWallet] = await ethers.getSigners();
        const LinkToken = await ethers.getContractFactory("LinkToken");
        linkToken = await LinkToken.deploy();
        const VRFCoordinatorMock = await ethers.getContractFactory("VRFCoordinatorMock");
        vrfCoordinatorMock = await VRFCoordinatorMock.deploy(linkToken.address);
        const Factory = await ethers.getContractFactory("Factory");
        factory = await Factory.deploy();
        await factory.createKingsCastle(BigNumber.from("115740740741"), 10, 1); // 0.01 ETH/DAY
        const kingsCastleAddress = await factory.getKingsCastleAt(0);
        kingsCastle = await ethers.getContractAt("KingsCastle", kingsCastleAddress);
        distribution = [
            ethers.utils.parseEther("1"),
            ethers.utils.parseEther("4"),
            ethers.utils.parseEther("1"),
            ethers.utils.parseEther("1.5")
        ];
        await factory.createLottery(
            vrfCoordinatorMock.address,
            linkToken.address,
            kingsCastle.address,
            seaOfRedemption.address,
            devWallet.address,
            ethers.utils.parseEther("0.015"),
            500,
            distribution,
            "Mini Chad - Tier 1",
            "MCT1"
        );
        const lotteryAddress = await factory.getLotteryAt(0);
        lottery = await ethers.getContractAt("Lottery", lotteryAddress);
        await kingsCastle.setLottery(lottery.address);
    });
    
    it("Successful stake() execution", async() => {
        await linkToken.transfer(lottery.address, ethers.utils.parseEther("10"));
        await lottery.connect(alice).buyTickets(1, {value: ethers.utils.parseEther("0.015")})
        tx = await lottery.buyTickets(499, {value: ethers.utils.parseEther("7.485")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await expect(kingsCastle.stake(0)).to.be.revertedWith("sender is not the owner");
        await expect(kingsCastle.connect(alice).stake(0)).to.be.revertedWith("not a winning ticket");
        await lottery.approve(kingsCastle.address, 100);
        await kingsCastle.stake(100);
        tx = await lottery.connect(alice).buyTickets(500, {value: ethers.utils.parseEther("7.5")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.connect(alice).approve(kingsCastle.address, 600);
        await expect(kingsCastle.connect(alice).stake(600)).to.be.revertedWith("max amount of stakers has been reached");
        tx = await lottery.buyTickets(500, {value: ethers.utils.parseEther("7.5")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.approve(kingsCastle.address, 1100);
        await kingsCastle.stake(1100);
    });
});
