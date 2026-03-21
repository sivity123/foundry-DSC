// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract CodeConstants {
    uint256 public constant ANVIL_CHAINID = 31337;
    uint256 public constant MAINNET_CHAINID = 1;
    uint256 public constant SEPOLIA_CHAINID = 11155111;
    uint256 public constant NO_OF_TOKENS_EXPECTED = 2;
    uint256 public constant INITIAL_SUPPLy = 100;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__NotSupportedNetwork();

    struct NetworkConfig {
        address wBtc; //wEth wBtc and so on
        address wEth;
        address ethUsd;
        address btcUsd;
        address deployerAccount;
    }

    mapping(uint256 chainId => NetworkConfig networkConfig) private networkConfigs;

    //state variables
    uint8 private constant DECIMALS = 8;
    int256 private constant ETH_INITIAL_ANSWER = 2000e8;
    int256 private constant BTC_INITIAL_ANSWER = 10000e8;

    constructor() {
        networkConfigs[MAINNET_CHAINID] = getSepoliaConfig();
        networkConfigs[SEPOLIA_CHAINID] = createAndGetAnvilConfig();
    }

    function getConfigByChainid(uint256 _chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[_chainId].wBtc != address(0)) {
            return networkConfigs[_chainId];
        } else if (_chainId == ANVIL_CHAINID) {
            return createAndGetAnvilConfig();
        } else {
            revert HelperConfig__NotSupportedNetwork();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainid(block.chainid);
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory networkConfig) {
        address wrappedBtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        address wrappedEth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address EthForUsd = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        address BtcForUsd = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
        address account = 0x2974BA6bB2026C3Bd9dE2805Fc149168bFAc470F;

        networkConfig =
            NetworkConfig({
            wBtc: wrappedBtc, wEth: wrappedEth, ethUsd: EthForUsd, btcUsd: BtcForUsd, deployerAccount: account
        });
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory networkConfig) {
        address wrappedBtc = 0x4D68da063577F98C55166c7AF6955cF58a97b20A;
        address wrappedEth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        address EthForUsd = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        address BtcForUsd = 0xA39434A63A52E749F02807ae27335515BA4b07F7;
        address account = 0x2974BA6bB2026C3Bd9dE2805Fc149168bFAc470F;
        networkConfig =
            NetworkConfig({
            wBtc: wrappedBtc, wEth: wrappedEth, ethUsd: EthForUsd, btcUsd: BtcForUsd, deployerAccount: account
        });
    }

    function createAndGetAnvilConfig() public returns (NetworkConfig memory networkConfig) {
        vm.startBroadcast();
        //priceFeeds
        MockV3Aggregator ethPriceFeed = new MockV3Aggregator(DECIMALS, ETH_INITIAL_ANSWER);
        MockV3Aggregator btcPriceFeed = new MockV3Aggregator(DECIMALS, BTC_INITIAL_ANSWER);
        // ERC20 version eth,btc
        ERC20Mock wrappedEth = new ERC20Mock("Wrapped ETH", "wEth");
        ERC20Mock wrappedBtc = new ERC20Mock("Wrapped BTC", "wBtc");
        vm.stopBroadcast();

        networkConfig = NetworkConfig({
            wBtc: address(wrappedBtc),
            wEth: address(wrappedEth),
            ethUsd: address(ethPriceFeed),
            btcUsd: address(btcPriceFeed),
            deployerAccount: DEFAULT_SENDER
        });
    }
}
