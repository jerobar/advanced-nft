// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";

interface ITarget {
    function getTrue() external pure returns (bool);
}

/**
 * `TargetOne` contract demonstrates how extcodesize/address.code.length checks
 * may be bypassed when called from within a constructor.
 */
contract TargetOne {
    using Address for address;

    /**
     * @dev Checks `account` address is not a contract account via its
     * extcodesize/address.code.length using OpenZeppelin's `Address` util.
     */
    modifier isNotContract(address account) {
        require(
            !account.isContract(),
            "TargetOne: Message sender cannot be a contract"
        );
        _;
    }

    /**
     * @dev Returns true if `msg.sender` is not a contract address.
     *
     * Requires:
     *
     * - OpenZeppelin `Address` util's `isContract` returns false for `account`
     *
     * Note: The `isContract` function relies on a check of the
     * extcodesize/address.code.length to determine whether the account is a
     * contract. This check will fail when called from within a constructor.
     */
    function getTrue() external view isNotContract(msg.sender) returns (bool) {
        return true;
    }
}

/**
 * `TargetTwo` contract demonstrates how `msg.sender` == `tx.origin` may be
 * used to detect calls from contract accounts even from the constructor.
 */
contract TargetTwo {
    /**
     * @dev Checks `msg.sender` is equal to `tx.origin` to detect contract
     * accounts.
     */
    modifier isNotContract() {
        require(
            msg.sender == tx.origin,
            "TargetTwo: Message sender cannot be a contract"
        );
        _;
    }

    /**
     * @dev Returns true if caller is not a contract address.
     *
     * Requires:
     *
     * - `msg.sender` == `tx.origin`
     */
    function getTrue() external view isNotContract returns (bool) {
        return true;
    }
}

/**
 * `Caller` contract tests the ability of target contracts to restrict calls
 * from contract addresses.
 */
contract Caller {
    bool public targetCalledSuccessfully = false;

    /**
     * @dev Constructor calls target contract's `getTrue` and stores the result
     * in `targetCalledSuccessfully`.
     */
    constructor(address targetContractAddress) {
        targetCalledSuccessfully = ITarget(targetContractAddress).getTrue();
    }
}
