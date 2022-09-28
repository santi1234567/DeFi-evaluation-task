// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {ILendingPool} from "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";
import {DataTypes} from "@aave/protocol-v2/contracts/protocol/libraries/types/DataTypes.sol";
import {IERC20} from "@aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {IProtocolDataProvider} from "./interfaces/IProtocolDataProvider.sol";
import {ILendingPoolAddressesProvider} from "@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";

//import {IAToken} from "@aave/protocol-v2/contracts/interfaces/IAToken.sol";
//import {IStableDebtToken} from "@aave/protocol-v2/contracts/interfaces/IStableDebtToken.sol";
//import {IVariableDebtToken} from "@aave/protocol-v2/contracts/interfaces/IVariableDebtToken.sol";

contract AaveV2Wrapper {
    // Mainnet
    address constant PROTOCOL_DATA_PROVIDER =
        address(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);
    IProtocolDataProvider constant dataProvider =
        IProtocolDataProvider(PROTOCOL_DATA_PROVIDER);

    address POOL;
    ILendingPool lendingPool;

    constructor() public {
        POOL = ILendingPoolAddressesProvider(dataProvider.ADDRESSES_PROVIDER())
            .getLendingPool();
        lendingPool = ILendingPool(POOL);
    }

    mapping(address => mapping(address => uint256)) userDeposits;
    mapping(address => mapping(address => mapping(uint256 => uint256))) userDebts;

    event DepositAndBorrow(
        address collateralToken,
        uint256 collateralAmount,
        address debtToken,
        uint256 debtAmount,
        uint256 rateMode,
        address user
    );

    event PaybackAndWithdraw(
        address collateralToken,
        uint256 collateralAmount,
        address debtToken,
        uint256 debtAmount,
        uint256 rateMode,
        address user
    );

    // deposit collateralToken, borrow debtToken. Must recieve contract address and amounts for both tokens.
    // Note: Balance to deposit collateral can be taken from caller
    function depositAndBorrow(
        address collateralToken,
        uint256 collateralAmount,
        address debtToken,
        uint256 debtAmount,
        uint256 rateMode
    ) public {
        IERC20(collateralToken).transferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );
        IERC20(collateralToken).approve(POOL, collateralAmount);
        _deposit(collateralToken, collateralAmount);
        userDeposits[collateralToken][msg.sender] += collateralAmount;

        /*         (
            address aDebtTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress
        ) = dataProvider.getReserveTokensAddresses(debtToken); */
        _borrow(debtToken, debtAmount, rateMode);
        userDebts[debtToken][msg.sender][rateMode] += debtAmount;
        IERC20(debtToken).transfer(msg.sender, debtAmount);

        emit DepositAndBorrow(
            collateralToken,
            collateralAmount,
            debtToken,
            debtAmount,
            rateMode,
            msg.sender
        );
    }

    // payback debtToken and withdraw the collateralToken
    // Note: Balance to payback debt can be taken from caller
    function paybackAndWithdraw(
        address collateralToken,
        uint256 collateralAmount,
        address debtToken,
        uint256 debtAmount,
        uint256 rateMode
    ) public {
        IERC20(debtToken).transferFrom(msg.sender, address(this), debtAmount);
        IERC20(debtToken).approve(POOL, debtAmount);
        _repay(debtToken, debtAmount, rateMode);
        userDebts[debtToken][msg.sender][rateMode] -= debtAmount;

        _withdraw(collateralToken, collateralAmount);

        IERC20(collateralToken).transfer(msg.sender, collateralAmount);
        userDeposits[collateralToken][msg.sender] -= collateralAmount;

        emit PaybackAndWithdraw(
            collateralToken,
            collateralAmount,
            debtToken,
            debtAmount,
            rateMode,
            msg.sender
        );
    }

    /**
     * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
     * - E.g. User deposits 100 USDC and gets in return 100 aUSDC
     * Note: When depositing, the LendingPool contract must have allowance() to spend funds on behalf of msg.sender for at-least amount for the asset being deposited. This can be done via the standard ERC20 approve() method.
     * @param token The address of the underlying asset to deposit
     * @param amount The amount to be deposited
     **/
    function _deposit(address token, uint256 amount) internal {
        lendingPool.deposit(token, amount, address(this), 0);
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
     **/
    function _borrow(
        address token,
        uint256 amount,
        uint256 interestRateMode
    ) internal {
        lendingPool.borrow(token, amount, interestRateMode, 0, address(this));
    }

    /**
     * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
     * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
     * @param token The address of the underlying asset to withdraw
     * @param amount The underlying amount to be withdrawn
     *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
     * @return The final amount withdrawn
     **/
    function _withdraw(address token, uint256 amount)
        internal
        returns (uint256)
    {
        return lendingPool.withdraw(token, amount, address(this));
    }

    /**
     * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
     * - E.g. User repays 100 USDC, burning 100 variable/stable debt tokens of the `onBehalfOf` address
     * @param token The address of the borrowed underlying asset previously borrowed
     * @param amount The amount to repay
     * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
     * @param rateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
     * @return The final amount repaid
     **/
    function _repay(
        address token,
        uint256 amount,
        uint256 rateMode
    ) internal returns (uint256) {
        return lendingPool.repay(token, amount, rateMode, address(this));
    }

    function getUserDepositBalance(address token, address user)
        public
        view
        returns (uint256)
    {
        return userDeposits[token][user];
    }

    function getUserDebtBalance(
        address token,
        address user,
        uint256 rateMode
    ) public view returns (uint256) {
        return userDebts[token][user][rateMode];
    }
}
