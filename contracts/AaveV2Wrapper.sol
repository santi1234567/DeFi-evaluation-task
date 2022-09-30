// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {ILendingPool} from "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";
import {IERC20} from "@aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {IProtocolDataProvider} from "./interfaces/IProtocolDataProvider.sol";
import {ILendingPoolAddressesProvider} from "@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";

contract AaveV2Wrapper {
    address owner;
    address[] validUsers;

    // Mainnet
    address public constant PROTOCOL_DATA_PROVIDER =
        address(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);
    IProtocolDataProvider public constant dataProvider =
        IProtocolDataProvider(PROTOCOL_DATA_PROVIDER);

    address POOL;
    ILendingPool immutable lendingPool;

    constructor() public {
        POOL = ILendingPoolAddressesProvider(dataProvider.ADDRESSES_PROVIDER())
            .getLendingPool();
        lendingPool = ILendingPool(POOL);
        owner = msg.sender;
    }

    // Events
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

    // Modifiers

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier OnlyValidUser() {
        require(_isValidUser(msg.sender), "Not a valid user");
        _;
    }

    // Public functions

    /**
     * @dev collateralToken, borrow debtToken. Must recieve contract address and amounts for both tokens.
     * Note: Balance to deposit collateral can be taken from caller
     * @param collateralToken The address of the underlying asset to deposit as collateral
     * @param collateralAmount The amount of the underlying asset to deposit as collateral
     * @param debtToken The address of the token to be borrowed
     * @param debtToken The amount of the token to be borrowed
     **/
    function depositAndBorrow(
        address collateralToken,
        uint256 collateralAmount,
        address debtToken,
        uint256 debtAmount,
        uint256 rateMode
    ) public OnlyValidUser {
        if (collateralAmount > 0) {
            IERC20(collateralToken).transferFrom(
                msg.sender,
                address(this),
                collateralAmount
            );
            IERC20(collateralToken).approve(POOL, collateralAmount);
            _deposit(collateralToken, collateralAmount);
            lendingPool.setUserUseReserveAsCollateral(collateralToken, true);
        }

        if (debtAmount > 0) {
            _borrow(debtToken, debtAmount, rateMode);
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
    }

    /**
     * @dev payback debtToken and withdraw the collateralToken
     * Note: Balance to payback debt can be taken from caller
     * @param collateralToken The address of the underlying asset to withdraw
     * @param collateralAmount The amount of the underlying asset to withdraw
     * @param debtToken The address of the debt token to be repayed
     * @param debtToken The amount of the debt token to be repayed
     **/
    function paybackAndWithdraw(
        address collateralToken,
        uint256 collateralAmount,
        address debtToken,
        uint256 debtAmount,
        uint256 rateMode
    ) public OnlyValidUser returns (uint256, uint256) {
        uint256 amountRepayed;
        if (debtAmount > 0) {
            IERC20(debtToken).transferFrom(
                msg.sender,
                address(this),
                debtAmount
            );
            IERC20(debtToken).approve(POOL, debtAmount);
            amountRepayed = _repay(debtToken, debtAmount, rateMode);
            // If there are remaining funds from the user after repaying, return them
            if (amountRepayed < debtAmount) {
                IERC20(debtToken).transfer(
                    msg.sender,
                    debtAmount - amountRepayed
                );
            }
        } else {
            amountRepayed = debtAmount;
        }
        uint256 amountWithdrawn;
        if (collateralAmount > 0) {
            amountWithdrawn = _withdraw(
                collateralToken,
                collateralAmount,
                msg.sender
            );
        } else {
            amountWithdrawn = collateralAmount;
        }

        emit PaybackAndWithdraw(
            collateralToken,
            amountWithdrawn,
            debtToken,
            amountRepayed,
            rateMode,
            msg.sender
        );
        return (amountRepayed, amountWithdrawn);
    }

    // Internal functions

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
     * @param user The address who will recieve thee underlying asset.
     * @return The final amount withdrawn
     **/
    function _withdraw(
        address token,
        uint256 amount,
        address user
    ) internal returns (uint256) {
        return lendingPool.withdraw(token, amount, user);
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

    function _isValidUser(address userAddress) internal view returns (bool) {
        for (uint256 i = 0; i < validUsers.length; i++) {
            if (validUsers[i] == userAddress) {
                return true;
            }
        }
        return false;
    }

    // Setters

    function addValidUser(address userAddress) public onlyOwner {
        validUsers.push(userAddress);
    }

    function removeValidUser(address userAddress) public onlyOwner {
        for (uint256 i = 0; i < validUsers.length; i++) {
            if (validUsers[i] == userAddress) {
                validUsers[i] = validUsers[validUsers.length - 1];
                validUsers.pop();
            }
        }
    }

    // Getters

    function getValidUsers() public view returns (address[] memory) {
        return validUsers;
    }
}
