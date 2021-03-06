require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('solidity-coverage');
require("hardhat-gas-reporter");
require("dotenv").config();
const { MAINNET, REPORT_GAS, API_KEY } = process.env;

module.exports = {
    solidity: {
        compilers: [{
            version: "0.8.7",
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200
                }
            }
        },
        {
            version: "0.4.24"
        }]
    },
    gasReporter: {
        currency: 'USD',
        enabled: (REPORT_GAS === "true") ? true : false
    },
    etherscan: {
        apiKey: API_KEY
    }
};
