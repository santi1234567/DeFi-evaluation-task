require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
const CHAIN_IDS = {
	hardhat: 31337, // chain ID for hardhat testing
};

const FORK_BLOCK = 15618588;

const infuraProjectId = process.env.INFURA_PROJECT_ID;
const privateKey = process.env.DEPLOYER_SIGNER_PRIVATE_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
	solidity: "0.6.12",
	networks: {
		hardhat: {
			chainId: CHAIN_IDS.hardhat,
			forking: {
				// Using Infura
				url: `https://mainnet.infura.io/v3/${infuraProjectId}`, // ${infuraProjectId} - must be your infura API key
				blockNumber: FORK_BLOCK, // a specific block number with which you want to work
			},
		},
	},
};
