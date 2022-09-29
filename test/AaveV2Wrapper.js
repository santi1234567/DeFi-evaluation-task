const ERC20 = require("./ABI/ERC20.json");
const StableDebtTokenABI =
	require("@aave/protocol-v2/artifacts/contracts/protocol/tokenization/StableDebtToken.sol/StableDebtToken.json").abi;
const IATokenABI =
	require("@aave/protocol-v2/artifacts/contracts/interfaces/IAToken.sol/IAToken.json").abi;
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const mainnetDAIContractAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const mainnetaDAIContractAddress = "0x028171bCA77440897B824Ca71D1c56caC55b68A3";
const mainnetWETHContractAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const mainnetWETHStableDebtContractAddress =
	"0x4e977830ba4bd783C0BB7F15d3e243f73FF57121";
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
		it("Should deposit and borrow funds correctly", async function () {
			const { aaveV2Wrapper, dai, weth, owner, tokenHolder } =
				await loadFixture(deployFixture);
			const collateralToken = dai.address;
			const collateralAmount = ethers.utils.parseUnits("10000");
			const debtToken = weth.address;
			const debtAmount = ethers.utils.parseEther("1");
			const rateMode = 1; // Stable
			const previousWETHBalance = await weth.balanceOf(tokenHolder.address);

			await dai
				.connect(tokenHolder)
				.approve(aaveV2Wrapper.address, collateralAmount);
			expect(
				await aaveV2Wrapper
					.connect(tokenHolder)
					.depositAndBorrow(
						collateralToken,
						collateralAmount,
						debtToken,
						debtAmount,
						rateMode
					)
			)
				.to.emit(aaveV2Wrapper, "DepositAndBorrow")
				.withArgs(
					collateralToken,
					collateralAmount,
					debtAmount,
					debtAmount,
					rateMode,
					tokenHolder.address
				);
			const aTokenBalance = await new ethers.Contract(
				mainnetaDAIContractAddress,
				IATokenABI,
				tokenHolder
			).balanceOf(aaveV2Wrapper.address);
			expect(aTokenBalance).to.be.greaterThanOrEqual(collateralAmount);
			const stableDebtTokenBalance = await new ethers.Contract(
				mainnetWETHStableDebtContractAddress,
				StableDebtTokenABI,
				tokenHolder
			).balanceOf(aaveV2Wrapper.address);
			expect(stableDebtTokenBalance).to.be.greaterThanOrEqual(debtAmount);

			const newWETHBalance = await weth.balanceOf(tokenHolder.address);
			expect(newWETHBalance).to.equal(debtAmount.add(previousWETHBalance));

			expect(
				await aaveV2Wrapper.getUserDepositBalance(
					mainnetDAIContractAddress,
					tokenHolder.address
				)
			).to.equal(collateralAmount);
			expect(
				await aaveV2Wrapper.getUserDebtBalance(
					mainnetWETHContractAddress,
					tokenHolder.address,
					rateMode
				)
			).to.equal(debtAmount);
		});
		it("Should allow to deposit without borrowing funds", async function () {
			const { aaveV2Wrapper, dai, weth, owner, tokenHolder } =
				await loadFixture(deployFixture);
			const collateralToken = dai.address;
			const collateralAmount = ethers.utils.parseUnits("10000");
			const debtToken = weth.address;
			const debtAmount = 0;
			const rateMode = 1; // Stable
			await dai
				.connect(tokenHolder)
				.approve(aaveV2Wrapper.address, collateralAmount);
			expect(
				await aaveV2Wrapper
					.connect(tokenHolder)
					.depositAndBorrow(
						collateralToken,
						collateralAmount,
						debtToken,
						debtAmount,
						rateMode
					)
			)
				.to.emit(aaveV2Wrapper, "DepositAndBorrow")
				.withArgs(
					collateralToken,
					collateralAmount,
					debtAmount,
					debtAmount,
					rateMode,
					tokenHolder.address
				);
			const aTokenBalance = await new ethers.Contract(
				mainnetaDAIContractAddress,
				IATokenABI,
				tokenHolder
			).balanceOf(aaveV2Wrapper.address);
			expect(aTokenBalance).to.be.greaterThanOrEqual(collateralAmount);
			const stableDebtTokenBalance = await new ethers.Contract(
				mainnetWETHStableDebtContractAddress,
				StableDebtTokenABI,
				tokenHolder
			).balanceOf(aaveV2Wrapper.address);
			expect(stableDebtTokenBalance).to.equal(ethers.BigNumber.from(0));
			expect(
				await aaveV2Wrapper.getUserDepositBalance(
					mainnetDAIContractAddress,
					tokenHolder.address
				)
			).to.equal(collateralAmount);
			expect(
				await aaveV2Wrapper.getUserDebtBalance(
					mainnetWETHContractAddress,
					tokenHolder.address,
					rateMode
				)
			).to.equal(ethers.BigNumber.from(0));
		});

		it("Should allow to borrow without depositing funds", async function () {
			const { aaveV2Wrapper, dai, weth, owner, tokenHolder } =
				await loadFixture(deployFixture);
			const collateralToken = dai.address;
			const collateralAmount = ethers.utils.parseUnits("10000");
			const debtToken = weth.address;
			const debtAmount = ethers.utils.parseEther("1");
			const rateMode = 1; // Stable
			await dai
				.connect(tokenHolder)
				.approve(aaveV2Wrapper.address, collateralAmount);
			await aaveV2Wrapper
				.connect(tokenHolder)
				.depositAndBorrow(
					collateralToken,
					collateralAmount,
					debtToken,
					ethers.BigNumber.from(0),
					rateMode
				);
			await aaveV2Wrapper
				.connect(tokenHolder)
				.depositAndBorrow(
					collateralToken,
					ethers.BigNumber.from(0),
					debtToken,
					debtAmount,
					rateMode
				);
			const stableDebtTokenBalance = await new ethers.Contract(
				mainnetWETHStableDebtContractAddress,
				StableDebtTokenABI,
				tokenHolder
			).balanceOf(aaveV2Wrapper.address);
			expect(stableDebtTokenBalance).to.be.greaterThanOrEqual(debtAmount);
			expect(
				await aaveV2Wrapper.getUserDebtBalance(
					mainnetWETHContractAddress,
					tokenHolder.address,
					rateMode
				)
			).to.equal(debtAmount);
		});

		it("Should allow a second user to borrow funds after first user deposited", async function () {
			const { aaveV2Wrapper, dai, weth, owner, tokenHolder } =
				await loadFixture(deployFixture);
			const collateralToken = dai.address;
			const collateralAmount = ethers.utils.parseUnits("10000");
			const debtToken = weth.address;
			const debtAmount = ethers.utils.parseEther("1");
			const rateMode = 1; // Stable

			await dai
				.connect(tokenHolder)
				.approve(aaveV2Wrapper.address, collateralAmount);

			await dai.connect(tokenHolder).transfer(owner.address, collateralAmount);

			await aaveV2Wrapper
				.connect(tokenHolder)
				.depositAndBorrow(
					collateralToken,
					collateralAmount,
					debtToken,
					debtAmount,
					rateMode
				);

			await dai.connect(owner).approve(aaveV2Wrapper.address, collateralAmount);

			await aaveV2Wrapper.depositAndBorrow(
				collateralToken,
				0,
				debtToken,
				debtAmount,
				rateMode
			);
			const stableDebtTokenBalance = await new ethers.Contract(
				mainnetWETHStableDebtContractAddress,
				StableDebtTokenABI,
				owner
			).balanceOf(aaveV2Wrapper.address);
			expect(stableDebtTokenBalance).to.be.greaterThanOrEqual(
				debtAmount.mul(2)
			);

			const newWETHBalance = await weth.balanceOf(owner.address);
			expect(newWETHBalance).to.equal(debtAmount);
			expect(
				await aaveV2Wrapper.getUserDepositBalance(
					mainnetDAIContractAddress,
					owner.address
				)
			).to.equal(0);
			expect(
				await aaveV2Wrapper.getUserDebtBalance(
					mainnetWETHContractAddress,
					owner.address,
					rateMode
				)
			).to.equal(debtAmount);
		});
	});

	describe("paybackAndWithdraw tests", function () {
		it("Should payback and withdraw funds correctly", async function () {
			const { aaveV2Wrapper, dai, weth, owner, tokenHolder } =
				await loadFixture(deployFixture);
			const collateralToken = dai.address;
			const collateralAmount = ethers.utils.parseUnits("10000");
			const debtToken = weth.address;
			const debtAmount = ethers.utils.parseEther("1");
			const rateMode = 1; // Stable
			const previousWETHBalance = await weth.balanceOf(tokenHolder.address);
			const withdrawAmount = collateralAmount.mul(8).div(10); //80%
			await dai
				.connect(tokenHolder)
				.approve(aaveV2Wrapper.address, collateralAmount);

			await aaveV2Wrapper
				.connect(tokenHolder)
				.depositAndBorrow(
					collateralToken,
					collateralAmount,
					debtToken,
					debtAmount,
					rateMode
				);

			await weth
				.connect(tokenHolder)
				.approve(aaveV2Wrapper.address, debtAmount);
			expect(
				await aaveV2Wrapper
					.connect(tokenHolder)
					.paybackAndWithdraw(
						collateralToken,
						withdrawAmount,
						debtToken,
						debtAmount,
						rateMode
					)
			)
				.to.emit(aaveV2Wrapper, "PaybackAndWithdraw")
				.withArgs(
					collateralToken,
					withdrawAmount,
					debtAmount,
					debtAmount,
					rateMode,
					tokenHolder.address
				);

			const aTokenBalance = await new ethers.Contract(
				mainnetaDAIContractAddress,
				IATokenABI,
				tokenHolder
			).balanceOf(aaveV2Wrapper.address);
			expect(aTokenBalance).to.be.lessThanOrEqual(
				collateralAmount.sub(withdrawAmount).mul(101).div(100) //101%, to contemplate interests
			);

			const stableDebtTokenBalance = await new ethers.Contract(
				mainnetWETHStableDebtContractAddress,
				StableDebtTokenABI,
				tokenHolder
			).balanceOf(aaveV2Wrapper.address);
			expect(stableDebtTokenBalance).to.be.lessThanOrEqual(
				debtAmount.div(100) //1 %, to contemplate interests
			);

			const newWETHBalance = await weth.balanceOf(tokenHolder.address);
			expect(newWETHBalance).to.equal(previousWETHBalance);

			expect(
				await aaveV2Wrapper.getUserDepositBalance(
					mainnetDAIContractAddress,
					tokenHolder.address
				)
			).to.equal(collateralAmount.sub(withdrawAmount));
			expect(
				await aaveV2Wrapper.getUserDebtBalance(
					mainnetWETHContractAddress,
					tokenHolder.address,
					rateMode
				)
			).to.equal(0);
		});
	});
});
