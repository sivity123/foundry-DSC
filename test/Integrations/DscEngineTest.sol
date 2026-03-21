// SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDsc} from "script/DeployDsc.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DscEngine} from "src/DscEngine.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
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
    address[] tokenAddresses;
    address[] priceFeedAddresses;

    uint256 private constant PRECISION = 1e18;
    uint256 private constant COLLATERAL_AMOUNT = 10;
    uint256 private constant REDEEM_AMOUNT = 4;
    uint256 private constant ADDTIONAL_AMOUNT = 1;
    uint256 private constant BURN_AMOUNT = 500;
    uint256 private constant MINT_AMOUNT = 10000;
    uint256 private constant ETH_USD_AMOUNT = 2000;
    uint256 private constant USD_AMOUNT = 1000;
    address user = makeAddr("USER");
    address liquidator = makeAddr("LIQUIDATOR");

    modifier collateralDeposited() {
        vm.startPrank(user);
        ERC20Mock(wEth).mint(user, COLLATERAL_AMOUNT + ADDTIONAL_AMOUNT);
        ERC20Mock(wEth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositeCollateral(wEth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

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
        uint256 actualUsd = dscEngine.getUsdValueOfTokenAmount(wEth, COLLATERAL_AMOUNT);
        console.log(actualUsd);
        uint256 expectedUsd = 20000;
        assertEq(actualUsd, expectedUsd);
    }

    function testTokenValueFromUsd() public view {
        //arrange
        uint256 actualEth = dscEngine.getTokenAmountFromUsd(wEth, ETH_USD_AMOUNT);
        console.log(actualEth);
        //
        uint256 expectedEth = 1e18;
        assert(actualEth == expectedEth);
    }

    function testDepositeZeroCollateralReverts() public {
        //arrange
        uint256 balanceOfUser = ERC20Mock(wEth).balanceOf(user);
        console.log(balanceOfUser);
        ERC20Mock(wEth).mint(user, COLLATERAL_AMOUNT + PRECISION);
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DscEngine.DSCEngine__mustBeMoreThanZero.selector);
        dscEngine.depositeCollateral(wEth, 0);
        vm.stopPrank();
        balanceOfUser = ERC20Mock(wEth).balanceOf(user);
        console.log(balanceOfUser);
    }

    function testRevertsOnMintingDscThatBreaksHealthFactor() public collateralDeposited {
        //arrange
        //deposited 20000 usd worth of collateral
        // can mint up to 10000USD worth of DSC
        vm.startPrank(user);
        dscEngine.mintDsc(ADDTIONAL_AMOUNT);
        (uint256 mintedDsc, uint256 totalCollateralValueInUsd) = dscEngine.getAccountInformations(user);
        uint256 totalDsc = MINT_AMOUNT + mintedDsc;
        uint256 expectedHealthFactor = dscEngine.checkHealthFactor(totalDsc, totalCollateralValueInUsd);
        console.log("Expected Health Factor: ", expectedHealthFactor);
        //a/a
        vm.expectRevert(
            abi.encodeWithSelector(DscEngine.DSCEngine__MustMaintainMinimumHealthFactor.selector, expectedHealthFactor)
        );
        dscEngine.mintDsc(MINT_AMOUNT);
        vm.stopPrank();
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

    function testGetAccountCollateralValue() public collateralDeposited {
        uint256 totalCollateralValue = dscEngine.getAccountCollateralValue(user);
        uint256 expectedTotalCollateralValue = ETH_USD_AMOUNT * COLLATERAL_AMOUNT;
        assertEq(totalCollateralValue, expectedTotalCollateralValue);
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

    function testRevertsDepositingUnsupportedCollateral() public {
        //arrange
        ERC20Mock unsupportedToken = new ERC20Mock("Unsupported Token", "UNST");
        vm.startPrank(user);
        vm.expectRevert(DscEngine.DSCEngine__InValidToken.selector);
        dscEngine.depositeCollateral(address(unsupportedToken), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testCanDepositeCollateralAndGetAccountInfo() public collateralDeposited {
        //Arrage
        (uint256 totalDsc, uint256 totalCollateralValue) = dscEngine.getAccountInformations(user);
        console.log("Total Dsc Minted:", totalDsc);
        console.log("total Collateral Value: ", totalCollateralValue);
        uint256 expectedTotalCollateralValue = 20000;
        assertEq(totalCollateralValue, expectedTotalCollateralValue);
    }

    function testDepositeAndMintDscWorksAndUpdatesUserBalance() public {
        uint256 userInitialDscBalance = decentralizedStableCoin.balanceOf(user);
        console.log("user's intitial dsc Balance: ", userInitialDscBalance);
        vm.startPrank(user);
        ERC20Mock(wEth).mint(user, COLLATERAL_AMOUNT + ADDTIONAL_AMOUNT); // minting 2 wEth tokens to user
        ERC20Mock(wEth).approve(address(dscEngine), COLLATERAL_AMOUNT); // approving dscEngine to spend 1 wEth token, internally it will transfer to it token balance
        dscEngine.depositeCollateralAndMintDsc(wEth, COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        uint256 userEndingDscBalance = decentralizedStableCoin.balanceOf(user);
        assertEq(userEndingDscBalance, userInitialDscBalance + MINT_AMOUNT);
    }

    //redeemCollateral

    function testRedeemCollateralRevertsOnInsfficientCollateral() public collateralDeposited {
        // a/a/a
        vm.expectRevert(DscEngine.DSCEngine__InsufficientCollateral.selector);
        vm.prank(user);
        dscEngine.redeemCollateral(wEth, COLLATERAL_AMOUNT + ADDTIONAL_AMOUNT);
    }

    function testRedeemCollateralUpdatesUserCollateralBalance() public collateralDeposited {
        //Arrange
        uint256 initialCollateralBacking = dscEngine.getCollateralBalanceInTokenAmount(wEth, user);
        console.log("initial Collateral Backing :", initialCollateralBacking);
        // Act
        vm.startPrank(user);
        dscEngine.mintDsc(1);
        dscEngine.redeemCollateral(wEth, REDEEM_AMOUNT);
        vm.stopPrank();
        uint256 endingCollateralBacking = dscEngine.getCollateralBalanceInTokenAmount(wEth, user);
        console.log("ending collateral baking: ", endingCollateralBacking);
        assertEq(initialCollateralBacking - REDEEM_AMOUNT, endingCollateralBacking);
    }

    function testRedeemCollateralForDsc() public collateralDeposited {
        //Arrange
        uint256 initialCollateralBacking = dscEngine.getCollateralBalanceInTokenAmount(wEth, user);
        vm.startPrank(user);
        uint256 userDscBalance = decentralizedStableCoin.balanceOf(user);
        dscEngine.mintDsc(MINT_AMOUNT / 10);
        console.log(userDscBalance);
        uint256 userInitialDscBalance = decentralizedStableCoin.balanceOf(user);
        decentralizedStableCoin.approve(address(dscEngine), BURN_AMOUNT);
        //20000 ETH, 10000 DSC minted,
        dscEngine.redeemCollateralForDsc(wEth, REDEEM_AMOUNT, BURN_AMOUNT); // burn amount  increase your health factor, which allows you to redeem more collateral
        uint256 userEndingDscBalance = decentralizedStableCoin.balanceOf(user);
        vm.stopPrank();
        uint256 endingCollateralBacking = dscEngine.getCollateralBalanceInTokenAmount(wEth, user);
        assertEq(initialCollateralBacking - REDEEM_AMOUNT, endingCollateralBacking);
        assertEq(userInitialDscBalance - BURN_AMOUNT, userEndingDscBalance);
    }

    // liquidate

    function testLiquidationRevertsOnHealthyUser() public collateralDeposited {
        //arrange
        vm.prank(user);
        dscEngine.mintDsc(MINT_AMOUNT);
        //act/assert
        vm.expectRevert(DscEngine.DSCEngine__HealthFactorIsFine.selector);
        vm.prank(liquidator);
        dscEngine.liquidate(wEth, user, USD_AMOUNT);
    }

    //burnDsc

    function testBurnDscReducesUserBalance() public collateralDeposited {
        //arrange
        vm.prank(user);
        dscEngine.mintDsc(MINT_AMOUNT);
        uint256 usersInitialDscBalance = decentralizedStableCoin.balanceOf(user);
        vm.startPrank(user);
        decentralizedStableCoin.approve(address(dscEngine), BURN_AMOUNT);
        dscEngine.burnDsc(BURN_AMOUNT);
        vm.stopPrank();
        uint256 usersEndingDscBalance = decentralizedStableCoin.balanceOf(user);
        assertEq(usersInitialDscBalance - BURN_AMOUNT, usersEndingDscBalance);
    }

    function testRedeemCollateralRevertOnLeadingToPoorHealthFactor() public collateralDeposited {
        uint256 userInitialWethBalance = ERC20Mock(wEth).balanceOf(user);
        console.log("userInitialbalance : ", userInitialWethBalance);
        vm.startPrank(user);
        dscEngine.mintDsc(10000); // half of 20000usd values deposited into the protocal
        vm.expectRevert(DscEngine.DSCEngine__MustMaintainMinimumHealthFactor.selector);
        dscEngine.redeemCollateral(wEth, 1);
        uint256 userEndingBalance = ERC20Mock(wEth).balanceOf(user);
        console.log("userEndingBalance : ", userEndingBalance);
    }
}

