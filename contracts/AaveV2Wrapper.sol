// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {ILendingPool} from "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";

contract AaveV2Wrapper {
    // deposit collateralToken , borrow debtToken. Must recieve contract address and amounts for both tokens.
    // Note: Balance to deposit collateral can be taken from caller
    function depositAndBorrow(
        address collateralToken,
        uint256 collateralAmount,
        address debtToken,
        uint256 debtAmount
    ) public {}

    // payback debtToken and withdraw the collateralToken
    // Note: Balance to payback debt can be taken from caller
    function paybackAndWithdraw(
        address collateralToken,
        uint256 collateralAmount,
        address debtToken,
        uint256 debtAmount
    ) public {}

    // Deposits a certain amount of an asset into the protocol, minting the same amount of corresponding aTokens, and transferring them to the user.
    // Note: When depositing, the LendingPool contract must have allowance() to spend funds on behalf of msg.sender for at-least amount for the asset being deposited.
    // This can be done via the standard ERC20 approve() method.
    function _deposit(
        address pool,
        address token,
        address user,
        uint256 amount
    ) internal {
        ILendingPool(pool).deposit(token, amount, user, 0);
    }

    // Borrows amount of asset with interestRateMode, sending the amount to msg.sender, with the debt being incurred by user
    // Note: onBehalfOf must have enough collateral via deposit() or have delegated credit to msg.sender via approveDelegation().
    function _borrow(
        address pool,
        address token,
        uint256 amount,
        uint256 interestRateMode,
        address user
    ) internal {
        ILendingPool(pool).borrow(token, amount, interestRateMode, 0, user);
    }

    // Withdraws amount of the underlying asset, i.e. redeems the underlying token and burns the aTokens.
    // Note: When withdrawing to another address, msg.sender should have aToken that will be burned by lendingPool.
    function _withdraw(
        address pool,
        address token,
        uint256 amount,
        address to
    ) internal {}
}
