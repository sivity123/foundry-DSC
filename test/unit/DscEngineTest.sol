// SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDsc} from "script/DeployDsc.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DscEngine} from "src/DscEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract DscEngineTest is Test {
    DeployDsc deployDsc;
    DecentralizedStableCoin decentralizedStableCoin;
    DscEngine dscEngine;
    HelperConfig.NetworkConfig config;
    address ethUsd;
    address btcUsd;
    address wEth;
    address wBtc;
    address[]  tokenAddresses;
    address[]  priceFeedAddresses;

    uint256 private constant COLLATERAL_AMOUNT = 1;
    uint256 private constant ADDTIONAL_AMOUNT = 1;
    uint256 private constant MINT_AMOUNT = 1000;
    address user = makeAddr("USER");

    function setUp() public {
        vm.deal(user, 10000 ether);
        deployDsc = new DeployDsc();
        (decentralizedStableCoin, dscEngine, config) = deployDsc.run();
        ethUsd = config.ethUsd;
        btcUsd = config.btcUsd;
        wEth = config.wEth;
        wBtc = config.wBtc;
    }

    /////////////////////////////////
    // testConstructor //
    /////////////////////////////////

    function testRevertOnDifferentLengthOfAddresses() public {
        tokenAddresses = [config.wEth];
        priceFeedAddresses = [config.btcUsd, config.ethUsd];

        vm.expectRevert(DscEngine.DSCEngine__mustHaveEqualLengthBetweenTokenAndPriceFeedAddresses.selector);
        new DscEngine(tokenAddresses, priceFeedAddresses, address(decentralizedStableCoin));
    }

    /////////////////////////////////
    // priceFeedAddresses//
    /////////////////////////////////

    function testUsdValueOfTokenAmount() public view {
        // arrange
        uint256 actualEth = dscEngine.getUsdValueOfTokenAmount(wEth, COLLATERAL_AMOUNT);
        console.log(actualEth);
        uint256 expectedEth = 2000;
        assertEq(actualEth, expectedEth);
    }

    function testDepositeZeroCollateralReverts() public {
        //arrange
        uint256 balanceOfUser = ERC20Mock(wEth).balanceOf(user);
        console.log(balanceOfUser);
        ERC20Mock(wEth).mint(user, COLLATERAL_AMOUNT + 1e18);
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DscEngine.DSCEngine__mustBeMoreThanZero.selector);
        dscEngine.depositeCollateral(wEth, 0);
        vm.stopPrank();
        balanceOfUser = ERC20Mock(wEth).balanceOf(user);
        console.log(balanceOfUser);
    }

    function testDepositeCollateralRevertsForWhileTransferingWithoutApproval() public {
        //arrange
        uint256 balanceOfUser = ERC20Mock(wEth).balanceOf(user);
        console.log(balanceOfUser);
        ERC20Mock(wEth).mint(user, COLLATERAL_AMOUNT + ADDTIONAL_AMOUNT);
        vm.startPrank(user);
        // ERC20Mock(wEth).approve(address(dscEngine),AMOUNT);
        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientAllowance.selector);
        dscEngine.depositeCollateral(wEth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        balanceOfUser = ERC20Mock(wEth).balanceOf(user);
        console.log(balanceOfUser);
    }

    function testUserBalanceHasReduced() public {
        //arrange
        ERC20Mock(wEth).mint(user, COLLATERAL_AMOUNT + ADDTIONAL_AMOUNT);
        uint256 initialUserBalance = ERC20Mock(wEth).balanceOf(user);
        console.log(initialUserBalance);
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositeCollateral(wEth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        uint256 endingUserBalance = ERC20Mock(wEth).balanceOf(user);
        console.log(endingUserBalance);
        assertEq(initialUserBalance, endingUserBalance + COLLATERAL_AMOUNT);
    }

    ////////////////////////////
    // mintDSC//
    ////////////////////////////

    function testMintRevertOnPoorHealthFactor() public {
        ERC20Mock(wEth).mint(user, COLLATERAL_AMOUNT + ADDTIONAL_AMOUNT); //minting collateral tokens
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositeCollateral(wEth, COLLATERAL_AMOUNT);
        dscEngine.mintDsc(MINT_AMOUNT);
        vm.stopPrank();
    }
}
