const { ethers } = require("hardhat");

async function main() {
    [owner] = await ethers.getSigners();
    const KingsCastleFactory = await ethers.getContractFactory("KingsCastleFactory");
    const kingsCastleFactory = await KingsCastleFactory.deploy();
    await kingsCastleFactory.deployed();
    console.log("KingsCastleFactory deployed to:", kingsCastleFactory.address);
    console.log("Account balance:", (await owner.getBalance()).toString());
}

main().then(() => process.exit(0)).catch((error) => {
    console.error(error);
    process.exit(1);
});
