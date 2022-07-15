const { ethers } = require("hardhat");

async function main() {
    [owner] = await ethers.getSigners();
    const SeaOfRedemptionFactory = await ethers.getContractFactory("SeaOfRedemptionFactory");
    const seaOfRedemptionFactory = await SeaOfRedemptionFactory.deploy();
    await seaOfRedemptionFactory.deployed();
    console.log("SeaOfRedemptionFactory deployed to:", seaOfRedemptionFactory.address);
    console.log("Account balance:", (await owner.getBalance()).toString());
}

main().then(() => process.exit(0)).catch((error) => {
    console.error(error);
    process.exit(1);
});
