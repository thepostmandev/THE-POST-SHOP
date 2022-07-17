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

describe("SeaOfRedemption", function() {
    beforeEach(async function() {
        [owner, alice, bob, seaOfRedemption, devWallet] = await ethers.getSigners();
        const LinkToken = await ethers.getContractFactory("LinkToken");
        linkToken = await LinkToken.deploy();
        const VRFCoordinatorMock = await ethers.getContractFactory("VRFCoordinatorMock");
        vrfCoordinatorMock = await VRFCoordinatorMock.deploy(linkToken.address);
        const KingsCastleFactory = await ethers.getContractFactory("KingsCastleFactory");
        kingsCastleFactory = await KingsCastleFactory.deploy();
        await kingsCastleFactory.createKingsCastle(BigNumber.from("115740740741"), 10, 2); // 0.01 ETH/DAY
        const kingsCastleAddress = await kingsCastleFactory.getKingsCastleAt(0);
        const SeaOfRedemptionFactory = await ethers.getContractFactory("SeaOfRedemptionFactory");
        seaOfRedemptionFactory = await SeaOfRedemptionFactory.deploy();
        await seaOfRedemptionFactory.createSeaOfRedemption(BigNumber.from("115740740741"), 10, 2); // 0.01 ETH/DAY
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
        await linkToken.transfer(lottery.address, ethers.utils.parseEther("10"));
    });
    
    it("Successful stake() execution", async() => {
        await lottery.connect(alice).buyTickets(1, {value: ethers.utils.parseEther("0.015")})
        tx = await lottery.buyTickets(49, {value: ethers.utils.parseEther("0.735")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        tokens = [0];
        await expect(seaOfRedemption.stake(tokens)).to.be.revertedWith("sender is not the owner");
        tokens = [10];
        await expect(seaOfRedemption.stake(tokens)).to.be.revertedWith("contains excluded token");
        await lottery.approve(seaOfRedemption.address, 5);
        tokens = [5];
        await seaOfRedemption.stake(tokens);
        tx = await lottery.connect(alice).buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.connect(alice).approve(seaOfRedemption.address, 55);
        tokens = [55];
        await seaOfRedemption.connect(alice).stake(tokens);
        tx = await lottery.buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.approve(seaOfRedemption.address, 105);
        tokens = [105];
        await seaOfRedemption.stake(tokens);
        tx = await lottery.connect(bob).buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.connect(bob).approve(seaOfRedemption.address, 165);
        tokens = [165];
        await expect(seaOfRedemption.connect(bob).stake(tokens)).to.be.revertedWith("max amount of stakers has been reached");
    });
    
    it("Successful claim() execution", async() => {
        tx = await lottery.buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        tx = await lottery.connect(alice).buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.approve(seaOfRedemption.address, 20);
        tokens = [20];
        await seaOfRedemption.stake(tokens);
        await increaseTime(86399);
        await seaOfRedemption.claim();
        await expect(seaOfRedemption.connect(bob).claim()).to.be.revertedWith("forbidden to claim");
        await lottery.connect(alice).approve(seaOfRedemption.address, 70);
        tokens = [70];
        await seaOfRedemption.connect(alice).stake(tokens);
        await increaseTime(86399);
        await seaOfRedemption.connect(alice).claim();
        for (let i = 0; i < 9; i++) {
            await seaOfRedemption.connect(alice).claim();
        }
        await expect(seaOfRedemption.connect(alice).claim()).to.be.revertedWith("forbidden to claim");
        await increaseTime(15552000);
        await seaOfRedemption.claim();
        await seaOfRedemption.claim();
    });
    
    it("Successful onlyLottery() check", async() => {
        await expect(seaOfRedemption.addExcludedToken(10)).to.be.revertedWith("only lottery can call this function");
    });
    
    it("Successful updateRewardRate() execution", async() => {
        await expect(seaOfRedemption.updateRewardRate(0)).to.be.revertedWith("invalid reward rate");
        await seaOfRedemption.updateRewardRate(100);
    });
    
    it("Successful tokenOfOwnerByIndex() execution", async() => {
        await expect(seaOfRedemption.tokenOfOwnerByIndex(owner.address, 0)).to.be.reverted;
        tx = await lottery.buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.approve(seaOfRedemption.address, 20);
        tokens = [20];
        await seaOfRedemption.stake(tokens);
        await seaOfRedemption.tokenOfOwnerByIndex(owner.address, 0);
    });
    
    it("Successful viewUserInfo() execution", async() => {
        await seaOfRedemption.viewUserInfo(owner.address);
        tx = await lottery.buyTickets(50, {value: ethers.utils.parseEther("0.75")});
        receipt = await tx.wait();
        await callBackWithRandomness(receipt);
        await lottery.approve(seaOfRedemption.address, 20);
        tokens = [20];
        await seaOfRedemption.stake(tokens);
        await seaOfRedemption.viewUserInfo(owner.address);
    });
});
