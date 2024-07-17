// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from 'forge-std/Script.sol';
// import { HelperConfig } from './HelperConfig.s.sol';
import { HelperConfig } from '../script/HelperConfig.s.sol';
import { DevOpsTools } from 'lib/foundry-devops/src/DevOpsTools.sol';
import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';
import { MinimalAccount } from '../src/MinimalAccount.sol';
import { IEntryPoint } from 'lib/account-abstraction/contracts/interfaces/IEntryPoint.sol';
import { PackedUserOperation } from 'lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol';
import { MessageHashUtils } from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;
    uint256 constant LOCAL_CHAIN_ID = 31337;

    // Make sure you trust this user - He is able to send transactions on behalf of the account owner
    address constant RANDOM_APPROVER = 0x95B4E3e486f8460e3B0E42cb8420b2383784149f;

    function run() public {
        HelperConfig helperConfig = new HelperConfig();

        address dest = helperConfig.getConfig().usdc;
        uint256 value = 0;
        address minimalAccountAddress = DevOpsTools.get_most_recent_deployment('MinimalAccount', block.chainid);
        // This setup allows both the MinimalAccount and RANDOM_APPROVER to potentially spend the approved funds.
        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, RANDOM_APPROVER, 1e18);
        bytes memory executeCalldata = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        PackedUserOperation memory userOp = generateSignedUserOperation(minimalAccountAddress, executeCalldata, helperConfig.getConfig());
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(helperConfig.getConfig().account));
        vm.stopBroadcast();
    }

    function generateSignedUserOperation(address minimalAccount, bytes memory callData, HelperConfig.NetworkConfig memory config) public view returns (PackedUserOperation memory) {
        // 1. Generate unsigned data
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(minimalAccount, nonce, callData);

        // 2. Get the userOp hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp); // Hashes the content of the userOp (except the signature)
        // Convert the userOp hash into Eth hash
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // 3. Sign it
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        if (block.chainid == LOCAL_CHAIN_ID) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }
        userOp.signature = abi.encodePacked(r, s, v); // It's empty when the unsigned userOp is generated
        return userOp;
    }

    function _generateUnsignedUserOperation(address sender, uint256 nonce, bytes memory callData) internal pure returns (PackedUserOperation memory) {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return
            PackedUserOperation({
                sender: sender,
                nonce: nonce,
                initCode: hex'',
                callData: callData,
                accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit), //accountGasLimits -> bytes32 -> concatenation of verificationGas (16 bytes) and callGas (16 bytes)
                preVerificationGas: verificationGasLimit,
                gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
                paymasterAndData: hex'',
                signature: hex'' // Empty because the userOp is not signed yet
            });
    }
}
