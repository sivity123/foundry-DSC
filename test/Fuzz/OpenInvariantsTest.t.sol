// SPDX-License-Identifier:MIT

//what are our invarients

// 1) getter view function should never revert.(common Invarient check)
// 2) The totalSupply should be less than the collateral Value.

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDsc} from "script/DeployDsc.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DscEngine} from "src/DscEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OpenInvariantsTest is Test {
    DeployDsc deployDsc;
    DecentralizedStableCoin decentralizedStableCoin;
    DscEngine dscEngine;
    HelperConfig.NetworkConfig config;
    address wEth;
    address wBtc;

    function setUp() public {
        deployDsc = new DeployDsc();
        (decentralizedStableCoin, dscEngine, config) = deployDsc.run();
        targetContract(address(dscEngine));
        wEth = config.wEth;
        wBtc = config.wBtc;
    }

    function invariant_testProtocalHasMoreCollateralValueThanDebt() public view {
        //arrange
        uint256 wEthCollateralBalance = IERC20(wEth).balanceOf(address(dscEngine));
        uint256 wBtcCollaterlBalance = IERC20(config.wBtc).balanceOf(address(dscEngine));
        uint256 debtOfTheProtocal = decentralizedStableCoin.balanceOf(address(dscEngine));

        uint256 totalCollaterlaValue = dscEngine.getUsdValueOfTokenAmount(wEth, wEthCollateralBalance)
            + dscEngine.getUsdValueOfTokenAmount(wBtc, wBtcCollaterlBalance);

        assert(totalCollaterlaValue >= debtOfTheProtocal);
    }
}
