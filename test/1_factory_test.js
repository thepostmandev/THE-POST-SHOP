const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Factory", function() {
    beforeEach(async function() {
        [owner, alice, vrfCoordinator, link, kingsCastle, seaOfRedemption, devWallet] = await ethers.getSigners();
        const Factory = await ethers.getContractFactory("Factory");
        factory = await Factory.deploy();
    });
    
    it("Successful kings castle related functions execution", async() => {
        await expect(factory.createKingsCastle(
            0,
            100,
            100
        )).to.be.revertedWith("invalid reward rate");
        await expect(factory.createKingsCastle(100, 100, 100)).to.emit(factory, "KingsCastleCreated");
        expect(await factory.amountOfKingsCastles()).to.equal(1);
        await expect(factory.getKingsCastleAt(1)).to.be.revertedWith("invalid index");
        const kingsCastle = await factory.getKingsCastleAt(0);
        await expect(factory.removeKingsCastle(alice.address)).to.be.revertedWith("kings castle not found");
        await factory.removeKingsCastle(kingsCastle);
        await expect(factory.getKingsCastleAt(0)).to.be.revertedWith("empty set");
    });
    
    it("Successful lottery related functions execution", async() => {
        const distribution = [
            100,
            100,
            100,
            100
        ]
        await expect(factory.createLottery(
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
        )).to.emit(factory, "LotteryCreated");
        expect(await factory.amountOfLotteries()).to.equal(1);
        await expect(factory.getLotteryAt(1)).to.be.revertedWith("invalid index");
        const lottery = await factory.getLotteryAt(0);
        await expect(factory.removeLottery(alice.address)).to.be.revertedWith("lottery not found");
        await factory.removeLottery(lottery);
        await expect(factory.getLotteryAt(0)).to.be.revertedWith("empty set");
    });
});
