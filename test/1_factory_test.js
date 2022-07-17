const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Factories", function() {
    beforeEach(async function() {
        [owner, alice, vrfCoordinator, link, kingsCastle, seaOfRedemption, devWallet] = await ethers.getSigners();
        const KingsCastleFactory = await ethers.getContractFactory("KingsCastleFactory");
        kingsCastleFactory = await KingsCastleFactory.deploy();
        const SeaOfRedemptionFactory = await ethers.getContractFactory("SeaOfRedemptionFactory");
        seaOfRedemptionFactory = await SeaOfRedemptionFactory.deploy();
        const LotteryFactory = await ethers.getContractFactory("LotteryFactory");
        lotteryFactory = await LotteryFactory.deploy();
    });
    
    it("Successful kings castle related functions execution", async() => {
        await expect(kingsCastleFactory.createKingsCastle(100, 100, 100)).to.emit(kingsCastleFactory, "KingsCastleCreated");
        expect(await kingsCastleFactory.amountOfKingsCastles()).to.equal(1);
        const kingsCastle = await kingsCastleFactory.getKingsCastleAt(0);
        await kingsCastleFactory.removeKingsCastle(alice.address);
        await kingsCastleFactory.removeKingsCastle(kingsCastle);
        await expect(kingsCastleFactory.getKingsCastleAt(0)).to.be.reverted;
    });
    
    it("Successful sea of redemption related functions execution", async() => {
        await expect(seaOfRedemptionFactory.createSeaOfRedemption(100, 100, 100)).to.emit(seaOfRedemptionFactory, "SeaOfRedemptionCreated");
        expect(await seaOfRedemptionFactory.amountOfSeasOfRedemption()).to.equal(1);
        const seaOfRedemption = await seaOfRedemptionFactory.getSeaOfRedemptionAt(0);
        await seaOfRedemptionFactory.removeSeaOfRedemption(alice.address);
        await seaOfRedemptionFactory.removeSeaOfRedemption(seaOfRedemption);
        await expect(seaOfRedemptionFactory.getSeaOfRedemptionAt(0)).to.be.reverted;
    });
    
    it("Successful lottery related functions execution", async() => {
        const distribution = [100, 100, 100, 100]
        await expect(lotteryFactory.createLottery(
            vrfCoordinator.address,
            link.address,
            kingsCastle.address,
            seaOfRedemption.address,
            devWallet.address,
            100,
            500,
            distribution,
            "test",
            "test"
        )).to.emit(lotteryFactory, "LotteryCreated");
        expect(await lotteryFactory.amountOfLotteries()).to.equal(1);
        const lottery = await lotteryFactory.getLotteryAt(0);
        await lotteryFactory.removeLottery(alice.address)
        await lotteryFactory.removeLottery(lottery);
        await expect(lotteryFactory.getLotteryAt(0)).to.be.reverted;
    });
});
