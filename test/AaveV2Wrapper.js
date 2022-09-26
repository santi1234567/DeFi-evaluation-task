const ERC20 = require("./ABI/ERC20.json");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const mainnetDAIContractAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const mainnetWETHContractAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const tokenHolderAddress = "0xcd6eb888e76450ef584e8b51bb73c76ffba21ff2";
// Function which allows to convert any address to the signer which can sign transactions in a test
const impersonateAddress = async (address) => {
	const hre = require("hardhat");
	await hre.network.provider.request({
		method: "hardhat_impersonateAccount",
		params: [address],
	});
	const signer = await ethers.provider.getSigner(address);
	signer.address = signer._address;
	return signer;
};

// Function to increase time in mainnet fork
async function increaseTime(value) {
	if (!ethers.BigNumber.isBigNumber(value)) {
		value = ethers.BigNumber.from(value);
	}
	await ethers.provider.send("evm_increaseTime", [value.toNumber()]);
	await ethers.provider.send("evm_mine");
}

describe("AaveV2Wrapper tests", function () {
	async function deployFixture() {
		const [owner, otherAccount] = await ethers.getSigners();

		const AaveV2Wrapper = await ethers.getContractFactory("AaveV2Wrapper");
		const aaveV2Wrapper = await AaveV2Wrapper.deploy();
		const tokenHolder = await impersonateAddress(tokenHolderAddress);
		const dai = new ethers.Contract(
			mainnetDAIContractAddress,
			ERC20,
			tokenHolder
		);
		const weth = new ethers.Contract(mainnetWETHContractAddress, ERC20, owner);
		return { aaveV2Wrapper, dai, weth, owner, tokenHolder };
	}

	describe("depositAndBorrow tests", function () {
		it("Should set the right unlockTime", async function () {
			const { aaveV2Wrapper, dai, weth, owner, tokenHolder } =
				await loadFixture(deployFixture);
			const collateralToken = dai.address;
			const collateralAmount = ethers.utils.parseUnits("10000");
			const debtToken = weth.address;
			const debtAmount = ethers.utils.parseEther("1");

			/* 			await dai
				.connect(tokenHolder)
				.approve(
					"0x7d2768de32b0b80b7a3454c06bdac94a69ddc7a9",
					collateralAmount
				); 
        allowance = await dai.allowance(
          tokenHolder.address,
          "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"
        );*/
			await dai
				.connect(tokenHolder)
				.approve(aaveV2Wrapper.address, collateralAmount);

			const tx = await aaveV2Wrapper
				.connect(tokenHolder)
				.depositAndBorrow(
					collateralToken,
					collateralAmount,
					debtToken,
					debtAmount
				);
		});
	});

	describe("paybackAndWithdraw tests", function () {});
});
