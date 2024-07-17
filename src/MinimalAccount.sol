// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { IAccount } from 'lib/account-abstraction/contracts/interfaces/IAccount.sol';
import { PackedUserOperation } from 'lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol';
import { IEntryPoint } from 'lib/account-abstraction/contracts/interfaces/IEntryPoint.sol';
import { ECDSA } from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import { DevOpsTools } from 'lib/foundry-devops/src/DevOpsTools.sol';
import { MessageHashUtils } from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import { SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED } from 'lib/account-abstraction/contracts/core/Helpers.sol';

contract MinimalAccount is IAccount, Ownable {
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CanNotPayPrefund();
    error MinimalAccount__CallFailed(bytes);

    IEntryPoint private immutable i_entryPoint;

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            // OR: if (msg.sender == address(i_entryPoint) || msg.sender == owner())
            revert MinimalAccount__NotFromEntryPoint();
        } else {
            _;
        }
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            // OR: if (msg.sender == address(i_entryPoint) || msg.sender == owner())
            revert MinimalAccount__NotFromEntryPointOrOwner();
        } else {
            _;
        }
    }

    receive() external payable {}

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }


    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
        // This setup allows both the MinimalAccount and RANDOM_APPROVER to potentially spend the approved funds.
        (bool success, bytes memory result) = dest.call{ value: value }(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result); // We pass in the result !!!
        }
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) external requireFromEntryPoint returns (uint256 validationData) {
        validationData = _validateSignature(userOp, userOpHash);

        _payPrefund(missingAccountFunds);
    }

    // EIP-191 version of the signed hash
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash) internal view returns (uint256) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        (bool success, ) = payable(msg.sender).call{ value: missingAccountFunds }('');
        if (!success) {
            revert MinimalAccount__CanNotPayPrefund();
        }
    }

    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
