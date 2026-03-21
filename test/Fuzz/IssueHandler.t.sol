// SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DscEngine} from "src/DscEngine.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";


contract Handler is Test {
    uint32 private constant MAX_32_BYTE_SIZE = type(uint32).max;
    DecentralizedStableCoin decentralizedStableCoin;
    DscEngine dscEngine;
    ERC20Mock wEth;
    ERC20Mock wBtc;
    uint256 public timesDscMinted1;
    uint256 public timesDscMinted2;
    uint256 public timesDscMinted3;
    uint256 public timesCollateralRedeemed;
    uint256 public timesCollateralDeposited;
    address[] usersWithDepositedCollateral;

    constructor(DecentralizedStableCoin _decentralizedStableCoin, DscEngine _dscEngine) {
        decentralizedStableCoin = _decentralizedStableCoin;
        dscEngine = _dscEngine;
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        wEth = ERC20Mock(collateralTokens[0]);
        wBtc = ERC20Mock(collateralTokens[1]);
    }

    function depositeCollateral(uint256 _amount, uint256 _collateralSeed) public {
        // since invarient maintain the states, The total supply of minting collateral could exceeds uint256,
        // due to minting large amount's frequently which expects to cause overflow.

        ERC20Mock collateral = _pickRandomCollateralAddressFromSeed(_collateralSeed);
        _amount = bound(_amount, 1, MAX_32_BYTE_SIZE);
        collateral.mint(address(this), _amount);
        collateral.approve(address(dscEngine), _amount);
        // for (uint256 i = 0; i < usersWithDepositedCollateral.length; i++) {
        //     vm.assume(msg.sender != usersWithDepositedCollateral[i]);
        // }
        usersWithDepositedCollateral.push(msg.sender);
        dscEngine.depositeCollateral(address(collateral), _amount);
        timesCollateralDeposited++;
    }

    function _pickRandomCollateralAddressFromSeed(uint256 _collateralSeed) private view returns (ERC20Mock) {
        if (_collateralSeed % 2 == 0) {
            return wEth;
        } else {
            return wBtc;
        }
    }

    function redeemCollateral(uint256 _collateralSeed, uint256 _collateralAmount, uint256 _senderAddressFeed) public {
        ERC20Mock collateral = _pickRandomCollateralAddressFromSeed(_collateralSeed);
        if (usersWithDepositedCollateral.length == 0) return;
        address sender = usersWithDepositedCollateral[_senderAddressFeed % usersWithDepositedCollateral.length];
        uint256 maxCollateralAmount = dscEngine.getUserCollateralAmount(address(collateral), sender);
        _collateralAmount = bound(_collateralAmount, 0, maxCollateralAmount);
        //  vm.assume(_collateralAmount != 0); //if the condition fails to be true, This will let the
        // fuzzer to discard this function call
        if (_collateralAmount == 0) {
            return;
        }
        vm.prank(sender);
        dscEngine.redeemCollateral(address(collateral), _collateralAmount);
        timesCollateralRedeemed++;
    }

    function mintDsc(uint256 _dscAmount, uint256 _senderAddressFeed) public {
        timesDscMinted3++;
        if (usersWithDepositedCollateral.length == 0) return;
        address sender = usersWithDepositedCollateral[_senderAddressFeed % usersWithDepositedCollateral.length];
        // _dscAmount = bound(_dscAmount,1,MAX_32_BYTE_SIZE);
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = dscEngine.getAccountInformations(sender);
        int256 maxDscToMint = int256(totalCollateralValueInUsd / 2) - int256(totalDscMinted);
        // ex: 100Dsc / 1000 usd/2 500 usd - 100 usd => 400 usd,400, letting the user to test
        // based on healthfactor but without direclty dealing withit.
        timesDscMinted1++;
        // if(maxDscToMint<  0 ){
        //     return ;
        // }
        vm.assume(maxDscToMint >= 0);
        _dscAmount = bound(_dscAmount, 0, uint256(maxDscToMint));
        timesDscMinted2++;
        // if(_dscAmount == 0){
        //     return ;
        // }
        vm.assume(_dscAmount != 0);

        vm.prank(sender);
        dscEngine.mintDsc(_dscAmount);
    }
}
