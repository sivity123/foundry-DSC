//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DscEngine} from "src/DscEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DecentralizedStableCoin decentralizedStableCoin;
    DscEngine dscEngine;
    ERC20Mock wEth;
    ERC20Mock wBtc;
    uint32 private constant MAX_UINT32_SIZE = type(uint32).max;
    uint256 public timesDscMinted;
    uint256 public timesCollateralDeposited;
    uint256 public timesCollateralRedeemed;
    address[] userWithDepositedCollateral;
    MockV3Aggregator ethUsdPriceFeed;
    MockV3Aggregator btcUsdPriceFeed;

    constructor(DecentralizedStableCoin _decentralizedStableCoin, DscEngine _dscEngine) {
        decentralizedStableCoin = _decentralizedStableCoin;
        dscEngine = _dscEngine;
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        wEth = ERC20Mock(collateralTokens[0]);
        wBtc = ERC20Mock(collateralTokens[1]);
        ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(wEth)));
        btcUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(wBtc)));
    }

    function _pickCollateralAddressFromSeed(uint256 _seed) private view returns (ERC20Mock) {
        if (_seed % 2 == 0) {
            return wEth;
        }
        return wBtc;
    }

    function depositeCollateral(uint256 _collateralAddressSeed, uint256 _collateralAmount) public {
        ERC20Mock collateral = _pickCollateralAddressFromSeed(_collateralAddressSeed);
        _collateralAmount = bound(_collateralAmount, 1, MAX_UINT32_SIZE);
        console.log(address(this));
        console.log(msg.sender);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, _collateralAmount);
        collateral.approve(address(dscEngine), _collateralAmount);
        dscEngine.depositeCollateral(address(collateral), _collateralAmount);
        vm.stopPrank();
        timesCollateralDeposited++;
        userWithDepositedCollateral.push(msg.sender);
    }

    function mintDsc(uint256 _senderAddressFromSeed, uint256 _dscAmount) public {
        if (userWithDepositedCollateral.length == 0) {
            return;
        }
        address sender = userWithDepositedCollateral[_senderAddressFromSeed % userWithDepositedCollateral.length];
        (uint256 dscMinted, uint256 collteralValueInUsd) = dscEngine.getAccountInformations(sender);
        uint256 maxToMint = (collteralValueInUsd / 2) - (dscMinted);
        if (maxToMint == 0) {
            return;
        }
        _dscAmount = bound(_dscAmount, 1, maxToMint);

        //  if(_dscAmount == 0){
        //     return;
        // } // This line isn't needed since maxToMint on bound will never be zero.
        vm.prank(sender);
        dscEngine.mintDsc(_dscAmount);
        timesDscMinted++;
    }

    function redeemCollateral(uint256 _senderAddressSeed, uint256 _collateralAddressSeed, uint256 _collateralAmount)
        public returns(uint256)
    {
        if (userWithDepositedCollateral.length == 0) return 0;
        address sender = userWithDepositedCollateral[_senderAddressSeed % userWithDepositedCollateral.length];
        ERC20Mock collateral = _pickCollateralAddressFromSeed(_collateralAddressSeed);

        (uint256 dscMinted, uint256 totalCollateralValueInUsd) = dscEngine.getAccountInformations(sender);
        uint256 usdValueOfRedeemableCollateral = totalCollateralValueInUsd - (dscMinted*2);
        //redeemableValue collateral value In usd. 2000 usd

        uint256 maxRedeemableCollateralAmount =
            dscEngine.getTokenAmountFromUsd(address(collateral), usdValueOfRedeemableCollateral);
        //max redeemable collateral is combination of both collateral() 1 eth
        uint256 maxCollateralAmount = dscEngine.getUserCollateralAmount(address(collateral), sender);
        // 0.5 eth
        if(maxRedeemableCollateralAmount > maxCollateralAmount) return 0;
        if(maxRedeemableCollateralAmount == 0) return 0;
        _collateralAmount = bound(_collateralAmount, 1, maxRedeemableCollateralAmount);

        vm.startPrank(sender);
        timesCollateralRedeemed++;
        dscEngine.redeemCollateral(address(collateral), _collateralAmount);
        vm.stopPrank();
    }

    // function updatePriceFeedAnswer(uint32 _price) public {
    //     int256 price = int256(uint256(_price));
    //     ethUsdPriceFeed.updateAnswer(price);
    // } 
}


