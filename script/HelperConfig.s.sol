// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from 'forge-std/Script.sol';
import { ERC20Mock } from '@openzeppelin/contracts/mocks/token/ERC20Mock.sol';
import { EntryPoint } from 'lib/account-abstraction/contracts/core/EntryPoint.sol';

contract HelperConfig is Script {
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_MAINNET_CHAIN_ID = 42161;
    uint256 constant LOCAL_CHAIN_ID = 31337;

    address constant BURNER_WALLET = 0x601BD18adBE7F8c91ff5449193f4304D96e15a96; // My wallet from MetaMask
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    struct NetworkConfig {
        address entryPoint;
        address usdc;
        address account;
    }

    NetworkConfig public localNetworkConfig;

    // Should i remove networkConfig from the mapping ?
    mapping(uint256 chainId => NetworkConfig networkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ARBITRUM_MAINNET_CHAIN_ID] = getArbMainnetConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        if (block.chainid == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            return networkConfigs[block.chainid];
        }
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({ entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, usdc: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, account: BURNER_WALLET });
    }

    function getArbMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({ entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032, usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831, account: BURNER_WALLET });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        // address(0) is default one | could be empty
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mocks
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        ERC20Mock usdc = new ERC20Mock();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({ entryPoint: address(entryPoint), usdc: address(usdc), account: ANVIL_DEFAULT_ACCOUNT });
        return localNetworkConfig;
    }
}
