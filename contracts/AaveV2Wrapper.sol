// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {ILendingPool} from "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";
import {DataTypes} from "@aave/protocol-v2/contracts/protocol/libraries/types/DataTypes.sol";
import {IERC20} from "@aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract AaveV2Wrapper {
    // Goerli
    //address constant POOL = address(0x4bd5643ac6f66a5237E18bfA7d47cF22f1c9F210);

    // Mainnet
    address constant POOL = address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    // deposit collateralToken , borrow debtToken. Must recieve contract address and amounts for both tokens.
    // Note: Balance to deposit collateral can be taken from caller
    function depositAndBorrow(
        address collateralToken,
        uint256 collateralAmount,
        address debtToken,
        uint256 debtAmount
    ) public {
        _deposit(collateralToken, collateralAmount, msg.sender);
        /*  DataTypes.ReserveData memory aCollateralTokenAddress = ILendingPool(
            POOL_ADDRESS_PROVIDER
        ).getReserveData(collateralToken); */
        //DataTypes.InterestRateMode mode = DataTypes.InterestRateMode.STABLE;
        _borrow(debtToken, debtAmount, 1, msg.sender);
    }

    // payback debtToken and withdraw the collateralToken
    // Note: Balance to payback debt can be taken from caller
    function paybackAndWithdraw(
        address collateralToken,
        uint256 collateralAmount,
        address debtToken,
        uint256 debtAmount
    ) public {}

    /**
     * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
     * - E.g. User deposits 100 USDC and gets in return 100 aUSDC
     * Note: When depositing, the LendingPool contract must have allowance() to spend funds on behalf of msg.sender for at-least amount for the asset being deposited. This can be done via the standard ERC20 approve() method.
     * @param token The address of the underlying asset to deposit
     * @param amount The amount to be deposited
     * @param user The address that will receive the aTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
     *   is a different wallet
     **/
    function _deposit(
        address token,
        uint256 amount,
        address user
    ) internal {
        IERC20(token).transferFrom(user, address(this), amount);
        IERC20(token).approve(POOL, amount);
        ILendingPool(POOL).deposit(token, amount, user, 0);
    }

    /**
     * @dev Allows users to borrow a specific `amount` of the reserve underlying asset, provided that the borrower
     * already deposited enough collateral, or he was given enough allowance by a credit delegator on the
     * corresponding debt token (StableDebtToken or VariableDebtToken)
     * - E.g. User borrows 100 USDC passing as `onBehalfOf` his own address, receiving the 100 USDC in his wallet
     *   and 100 stable/variable debt tokens, depending on the `interestRateMode`
     * Note: user must have enough collateral via _deposit() or have delegated credit to msg.sender via approveDelegation().
     * @param token The address of the underlying asset to borrow
     * @param amount The amount to be borrowed
     * @param interestRateMode The interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
     * @param user Address of the user who will receive the debt. Should be the address of the borrower itself
     * calling the function if he wants to borrow against his own collateral, or the address of the credit delegator
     * if he has been given credit delegation allowance
     **/
    function _borrow(
        address token,
        uint256 amount,
        uint256 interestRateMode,
        address user
    ) internal {
        ILendingPool(POOL).borrow(token, amount, interestRateMode, 0, user);
    }

    /**
     * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
     * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
     * @param token The address of the underlying asset to withdraw
     * @param amount The underlying amount to be withdrawn
     *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
     * @param to Address that will receive the underlying, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     * @return The final amount withdrawn
     **/
    function _withdraw(
        address token,
        uint256 amount,
        address to
    ) internal returns (uint256) {
        return ILendingPool(POOL).withdraw(token, amount, to);
    }

    /**
     * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
     * - E.g. User repays 100 USDC, burning 100 variable/stable debt tokens of the `onBehalfOf` address
     * @param token The address of the borrowed underlying asset previously borrowed
     * @param amount The amount to repay
     * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
     * @param rateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
     * @param user Address of the user who will get his debt reduced/removed. Should be the address of the
     * user calling the function if he wants to reduce/remove his own debt, or the address of any other
     * other borrower whose debt should be removed
     * @return The final amount repaid
     **/
    function repay(
        address token,
        uint256 amount,
        uint256 rateMode,
        address user
    ) external returns (uint256) {
        return ILendingPool(POOL).repay(token, amount, rateMode, user);
    }
}
