const { ethers } = require("hardhat");

async function main() {
    [owner] = await ethers.getSigners();
    const LotteryFactory = await ethers.getContractFactory("LotteryFactory");
    const lotteryFactory = await LotteryFactory.deploy();
    await lotteryFactory.deployed();
    console.log("LotteryFactory deployed to:", lotteryFactory.address);
    console.log("Account balance:", (await owner.getBalance()).toString());
}

main().then(() => process.exit(0)).catch((error) => {
    console.error(error);
    process.exit(1);
});
