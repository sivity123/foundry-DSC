// SPDX-License-Identifier:MIT

//what are our invarients

// 1) getter view function should never revert.(common Invarient check)
// 2) The totalSupply should be less than the collateral Value.

// fuzzer will be programmed to avoid forbidden or making nonsenstial actions through handler contract

pragma solidity ^0.8.19;


import {Test,console} from "forge-std/Test.sol";
import {DeployDsc} from "script/DeployDsc.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DscEngine} from "src/DscEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import{Handler} from "./Handler.t.sol";


contract OpenInvariantsTest is Test{
DeployDsc deployDsc;
DecentralizedStableCoin decentralizedStableCoin;
DscEngine dscEngine;
HelperConfig.NetworkConfig config;
address wEth;
address wBtc;
Handler handler;


    function setUp() public {
        deployDsc = new DeployDsc();
        (decentralizedStableCoin,dscEngine,config) = deployDsc.run();
        handler = new Handler(decentralizedStableCoin,dscEngine);
        targetContract(address(handler));
        wEth = config.wEth;
        wBtc = config.wBtc;

    }


    function invariant_testProtocalHasMoreCollateralValueThanDebtThorughHandler()public view{
        //arrange 
        uint256 wEthCollateralBalance = IERC20(wEth).balanceOf(address(dscEngine));
        uint256 wBtcCollateralBalance = IERC20(wBtc).balanceOf(address(dscEngine));
        uint256 totalSupply = decentralizedStableCoin.totalSupply();
        uint256 wEthCollateralValue = dscEngine.getUsdValueOfTokenAmount(wEth,wEthCollateralBalance);
        uint256 wBtcCollateralValue = dscEngine.getUsdValueOfTokenAmount(wBtc,wBtcCollateralBalance);
        uint256 totalCollateralValue = wEthCollateralValue+wBtcCollateralValue;
        
        // uint256 totalCollaterlaValue = dscEngine.getUsdValueOfTokenAmount(wEth,wEthCollateralBalance)+dscEngine.getUsdValueOfTokenAmount(wBtc,wBtcCollaterlBalance);
       console.log("wEth: ",wEthCollateralBalance);
       console.log("wBtc: ", wBtcCollateralBalance);
       console.log("Debt of the Protocal(DscEngine) :",totalSupply);
       console.log("TotalCollateral Value : ",totalCollateralValue);
       console.log("Times Dsc Minted :",handler.timesDscMinted());
       console.log("Times Collateral Deposited",handler.timesCollateralDeposited());
       console.log("Times Collateral redeemed",handler.timesCollateralRedeemed());
       assert(totalCollateralValue >= totalSupply);
    }

    // function invariant_getterShouldNotRevert() public {
    //     getUserCollateralAmount(wEth,)  ;
    //     getUsdValueOfTokenAmount(address,uint256) ;
    //     getTokenAmountFromUsd(address,uint256) ;
    //     getNumberOfMintedDsc(address) ;
    //     getCollateralTokens(); 
    //     getCollateralBalanceInTokenAmount(address,address);
    //     getAccountInformations(address)  ;
    //     getAccountCollateralValue(address) ;
    //     checkHealthFactor(uint256,uint256)  ;

    // }


}