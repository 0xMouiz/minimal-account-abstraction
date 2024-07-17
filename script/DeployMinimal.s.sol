// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from 'forge-std/Script.sol';
import { MinimalAccount } from '../src/MinimalAccount.sol';
import { HelperConfig } from './HelperConfig.s.sol';

contract DeployMinimal is Script {
    function setUp() public {}

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // vm.startBroadcast
        // Description
        // Using the address that calls the test contract or the address / private key provided as the sender, has all subsequent calls (at this call depth only and excluding cheatcode calls) create transactions that can later be signed and sent onchain.
        vm.startBroadcast(config.account);
        MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);
        minimalAccount.transferOwnership(config.account); // from address(this) [deployer] to config.account
        vm.stopBroadcast();

        return (helperConfig, minimalAccount);
    }
}
