require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");

const mnemonic = process.env.MNEMONIC;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: "0.8.20",
    networks: {
        hardhat: {
            gas: "auto",
            accounts: {
                mnemonic,
            },
            chainId: 1337,
        },
        hyperEvmTestnet: {
            accounts: {
                mnemonic,
            },
            chainId: 998,
            url: 'https://api.hyperliquid-testnet.xyz/evm',
        }
    },
};
