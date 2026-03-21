// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {Script} from "forge-std/Script.sol";
import {DscEngine} from "src/DscEngine.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDsc is Script {
    DecentralizedStableCoin public decentralizedStableCoin;
    DscEngine public dscEngine;
    address[] tokenAddresses;
    address[] priceFeedAddresses;

    uint256 dummy;
    uint256 dummy2;
    uint256 dummy3;

    function run() external returns (DecentralizedStableCoin, DscEngine, HelperConfig.NetworkConfig memory) {
        HelperConfig.NetworkConfig memory config = getConstructorArguments();
        tokenAddresses = [config.wEth, config.wBtc];
        priceFeedAddresses = [config.ethUsd, config.btcUsd];
        vm.startBroadcast(config.deployerAccount);
        // creationg of dsc
        decentralizedStableCoin = new DecentralizedStableCoin();

        // creation of dscEngine to work with dsc
        dscEngine = new DscEngine(tokenAddresses, priceFeedAddresses, address(decentralizedStableCoin)); // tokenAddress array, priceFeedAddress array
        // transfering the dsc ownership to dscEngine to ensure engine can only acess specific functions like mint and burn.
        decentralizedStableCoin.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (decentralizedStableCoin, dscEngine, config);
    }

    function getConstructorArguments() public returns (HelperConfig.NetworkConfig memory) {
        HelperConfig helperConfig = new HelperConfig();
        return (helperConfig.getConfig());
    }
}
