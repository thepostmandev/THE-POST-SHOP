require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require('solidity-coverage');
require("dotenv").config();
const { MAINNET } = process.env;

module.exports = {
  solidity: {
    compilers: [
      {
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
      }
    ]
  }
};
