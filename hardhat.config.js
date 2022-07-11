require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require('solidity-coverage');
require("dotenv").config();
const { MAINNET } = process.env;

module.exports = {
    solidity: "0.8.7"
};
