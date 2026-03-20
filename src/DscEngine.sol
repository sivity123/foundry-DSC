// SPDX-License-Identifier:MIT

// Layout of Contract:
// version
// imports
// NatSpec documentation for the contract
// errors//if intendted to have outside the contract, put them here
// interfaces, libraries, contracts
//errors// if intended to have inside the contract, put them here
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "src/libraries/OracleLib.sol";

/**
 * @title DSCEngine
 * @author Sivanesh Sakthivel
 * @notice - Stablity Method(ALGORITHIMIC).
 * This contract is the base for our StableCoin.Which is going to be algorthimic the stablility
 * of our token for minting and burning, to keep the value non-volatile.
 * @notice  - Exogenous Collateral
 * Collateralization has done with crypto's (ETH&BTC), which is actually volatile.
 * @notice - Pegged To USD.
 * 1 token is pegged to 1USD.
 *
 * Simalar to DAI, if DAI is completely algorithimic,no fees and only backed with ETH&BTC.
 */
contract DscEngine is ReentrancyGuard {
    //////////////////////
    // ERRORS  //
    //////////////////////

    error DSCEngine__mustBeMoreThanZero();
    error DSCEngine__mustHaveEqualLengthBetweenTokenAndPriceFeedAddresses();
    error DSCEngine__InValidToken();
    error DSCEngine__MustMaintainMinimumHealthFactor();
    error DSCEngine__MintFailed();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsFine();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__InsufficientCollateral();


    //////////
    // Type
    /////////

    using OracleLib for AggregatorV3Interface;

    //////////////////////
    // State Variables  //
    //////////////////////
    //constants
    uint8 private constant SCALING_PRECISION = 18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHHOLD = 50; // collateralization should be 100% more than
    // DSC user has.
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant MIN_HEALTH_FACTOR = 1 * PRECISION;
    //immutable
    DecentralizedStableCoin private immutable i_decentralizedStableCoin;
    //mutables

    //mappings
    mapping(address token => address priceFeed) private s_priceFeed; // tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 numberOfTokensUserHolds) private s_dscMinted;
    //array
    address[] private s_collateralTokens;
    //////////////////////
    // EVENTS //
    //////////////////////

    event CollateralDeposited(address indexed user, address indexed collateralTokenAddress, uint256 depositedAmount);
    event CollateralReedemed(
        address indexed badUser,
        address indexed collateralTokenAddress,
        address indexed liquidatorAddress,
        uint256 amountOfCollateralReedemed
    );
    event DscBurned(address indexed badUser, address indexed liquidator, uint256 amountOfDscBurned);

    //////////////////////
    // modifiers//
    //////////////////////

    modifier mustBeMoreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__mustBeMoreThanZero();
        }
        _;
    }

    modifier isSupportedToken(address _token) {
        if (s_priceFeed[_token] == address(0)) {
            revert DSCEngine__InValidToken();
        }
        _;
    }

    //////////////////////
    // Functions//
    //////////////////////

    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses, address _dscAddress) {
        // i can set the parameter's to fixed array, to ensure correctness of the expected length
        if (_tokenAddresses.length != _priceFeedAddresses.length) {
            revert DSCEngine__mustHaveEqualLengthBetweenTokenAndPriceFeedAddresses();
        }
        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_priceFeed[_tokenAddresses[i]] = _priceFeedAddresses[i]; //Collateral token addresses to
            s_collateralTokens.push(_tokenAddresses[i]);
            //their priceFeed Addresses for USD.
        }
        i_decentralizedStableCoin = DecentralizedStableCoin(_dscAddress);
    }

    //////////////////////
    // External //
    //////////////////////

    /**
     * @param _collateralTokenAddress - Token address of collateral base to deposite collateral.
     * @param _collateralAmount -Amount of collateral will be depoiste.
     * @param _amountOfTokenToMint - Amount of tokens to be minted,(will work on the bases of
     * collateralization threshhold to maintain over-collateralization).
     * @notice - This function will let users to deposite their collateral and mint them tokens
     *  in one go
     */
    function depositeCollateralAndMintDsc(
        address _collateralTokenAddress,
        uint256 _collateralAmount,
        uint256 _amountOfTokenToMint
    ) external {
        depositeCollateral(_collateralTokenAddress, _collateralAmount);
        mintDsc(_amountOfTokenToMint);
    } //composition function

    function depositeCollateral(address _collateralTokenAddress, uint256 _collateralAmount)
        public
        mustBeMoreThanZero(_collateralAmount)
        isSupportedToken(_collateralTokenAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][_collateralTokenAddress] += _collateralAmount;
        emit CollateralDeposited(msg.sender, _collateralTokenAddress, _collateralAmount);

        bool success = IERC20(_collateralTokenAddress).transferFrom(msg.sender, address(this), _collateralAmount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        } // this will be unreachable, as transferFrom will revert on failure.
    }
    /**
     *
     * @param _collateralTokenAddress - Collateral token address which is need to be redeemed.
     * @param _amountOfCollateral - Amount of collateral need to be burned.
     * @param _amountOfTokenToBurn - amount of token to burn.
     * @notice - This function will let the user to burn their dsc and redeem their collateral at
     * one go.
     * @notice - redeemCollateral Internally checks the HealthFactor before transfering the
     * collateral amount.
     */

    function redeemCollateralForDsc(
        address _collateralTokenAddress,
        uint256 _amountOfCollateral,
        uint256 _amountOfTokenToBurn
    ) external {
        burnDsc(_amountOfTokenToBurn);
        redeemCollateral(_collateralTokenAddress, _amountOfCollateral);
    }

    function redeemCollateral(address _collateralTokenAddress, uint256 _amountOfCollateral)
        public
        mustBeMoreThanZero(_amountOfCollateral)
        isSupportedToken(_collateralTokenAddress)
        nonReentrant
    {
        // CEI - violated
        _redeemCollateral(_collateralTokenAddress, _amountOfCollateral, msg.sender, msg.sender);
        _revertPoorUserHealthFactor(msg.sender);
    }
    /**
     * @notice - Following the CEI pattern.
     * @notice - they must have more collateral value then the value of their minitng staleCoin
     * value.
     * @param  _amountOfTokenToMint - Number of tokens to be minted, Not the value fo the tokens.
     * @notice - using priceFeeds and comparing collateral value with the token they expect to mint
     * is a immediate process of this function.
     */

    function mintDsc(uint256 _amountOfTokenToMint) public {
        s_dscMinted[msg.sender] += _amountOfTokenToMint;
        _revertPoorUserHealthFactor(msg.sender);
        bool minted = i_decentralizedStableCoin.mint(msg.sender, _amountOfTokenToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc(uint256 _amountOfDsc) public {
        _burnDsc(_amountOfDsc, msg.sender, msg.sender);
        _revertPoorUserHealthFactor(msg.sender); // never going to revert - think about pulling at
            // the time auditing.
    } // To maintain over-collateralization.
    /**
     * @param _collateralTokenAddress - The Collateral token address(ex:wEth).
     * @param _user - The Account address of the user who is Broken the HealthFactor/threshhold policy
     * @param _amountOfDebtToCover - Amount of debt that the user wants to cover to liquidate the
     * user who failse to maintain threshhold policy.
     * @notice - you can partially liquidate the user by covering the user's debt.
     * @notice a Known bug would be if the protocal is 100% or undercollaterlized, then we wouldn't
     * be able to incentivize liquidators.
     * @dev - CEI - Follows the Checks,Effects and interactions pattern.
     */

    function liquidate(address _collateralTokenAddress, address _user, uint256 _amountOfDebtToCover) external {
        uint256 usersIntialhealthFactor = _healthFactor(_user);
        if (usersIntialhealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsFine();
        }
        uint256 tokenAmountFromDebtCoverd = getTokenAmountFromUsd(_collateralTokenAddress, _amountOfDebtToCover);
        uint256 bonusForLiquidators = (tokenAmountFromDebtCoverd * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCoverd + bonusForLiquidators;
        _redeemCollateral(_collateralTokenAddress, totalCollateralToRedeem, _user, msg.sender);
        _burnDsc(_amountOfDebtToCover, _user, msg.sender);
        uint256 usersEndingHealthFactor = _healthFactor(_user);
        if (usersEndingHealthFactor <= usersIntialhealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertPoorUserHealthFactor(msg.sender);
    }

    ////////////////////////
    // Internal & private //
    ////////////////////////

    function _burnDsc(uint256 _amountOfDsc, address _onBehalfOf, address _dscFrom) private {
        s_dscMinted[_onBehalfOf] -= _amountOfDsc;
        emit DscBurned(_onBehalfOf, _dscFrom, _amountOfDsc);
        bool success = i_decentralizedStableCoin.transferFrom(_dscFrom, address(this), _amountOfDsc);
        if (!success) {
            //unreachable
            revert DSCEngine__TransferFailed();
        }
        i_decentralizedStableCoin.burn(_amountOfDsc);
    }

    /**
     *
     */
    function _redeemCollateral(address _collateralTokenAddress, uint256 _amountOfCollateral, address _from, address _to)
        internal
    {
        // _from is the bad user whose collateral is being redeemed by the liquidator(_to)
        if (s_collateralDeposited[_from][_collateralTokenAddress] < _amountOfCollateral) {//
            revert DSCEngine__InsufficientCollateral();
        }
        s_collateralDeposited[_from][_collateralTokenAddress] -= _amountOfCollateral;
        emit CollateralReedemed(_from, _collateralTokenAddress, _to, _amountOfCollateral);
        bool success = IERC20(_collateralTokenAddress).transfer(_to, _amountOfCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @notice - Checks the healthFactor user by checking the total collateral value that user has,
     *  this helps to invoke liquidate if the user is fail to keep the collateral value.
     */
    function _healthFactor(address _user) private view returns (uint256) {
        //total number of tokens minted & total number collateral value in Usd.
        (uint256 totalDsc, uint256 totalCollateralValueInUsd) = _getAccountInformations(_user);
        uint256 healthFactor = _checkHealthFactor(totalDsc, totalCollateralValueInUsd);

        /*EX: 1000 DSC,2000 USD (collateral in ETH)
        2000*50 => 100000/100 => 1000*precsion(1e18)/totalDsc(1000 usd) = 0 (without precision)

        ex:2 
        1500USD,100 DSC
        1500*50 => 75000/100 => 750*precision /100 DSc => 75*1e17.

        ex:3 
        34000USD,15000 DSC
        34000*50 =>170000 /100 => 17000 *1e18/15000  => 1133e15
        */
        return healthFactor; // if totalDsc is 0 , will revert on panic error.
            //stating division by zero.
    }

    function _revertPoorUserHealthFactor(address _user) internal view {
        uint256 healthFactor = _healthFactor(_user);
        if (healthFactor < (MIN_HEALTH_FACTOR)) {
            revert DSCEngine__MustMaintainMinimumHealthFactor();
        }
    }

    function _getAccountInformations(address _user)
        private
        view
        returns (uint256 totalToken, uint256 totalCollateralValueInUsd)
    {
        totalToken = s_dscMinted[_user];
        totalCollateralValueInUsd = getAccountCollateralValue(_user);
    }

    function _checkHealthFactor(uint256 _totalDscMinted, uint256 _collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (_totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshhold =
            (_collateralValueInUsd * LIQUIDATION_THRESHHOLD) / LIQUIDATION_PRECISION;
        uint256 healthFactor = (collateralAdjustedForThreshhold * PRECISION) / _totalDscMinted;
        return healthFactor;
    }

    ////////////////////////
    // P&E read Functions//
    ////////////////////////

    function getAccountInformations(address _user)
        external
        view
        returns (uint256 totalToken, uint256 totalCollateralValueInUsd)
    {
        (totalToken, totalCollateralValueInUsd) = _getAccountInformations(_user);
    }

    function getAccountCollateralValue(address _user) public view returns (uint256) {
        uint256 totalCollateralValueInUsd;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[_user][token];
            uint256 tokenAmountValueInUsd = getUsdValueOfTokenAmount(token, amount);
            totalCollateralValueInUsd += tokenAmountValueInUsd; //scalling is needed
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValueOfTokenAmount(address _tokenAddress, uint256 _amount)
        public
        view
        returns (uint256 tokenAmountValueInUsd)
    {
        address priceFeedAddress = s_priceFeed[_tokenAddress];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        uint256 additionalDecimals = SCALING_PRECISION - priceFeed.decimals();
        tokenAmountValueInUsd = (_amount * (uint256(price) * 10 ** additionalDecimals)) / PRECISION;
    }

    function getTokenAmountFromUsd(address _collaterTokenAddress, uint256 _usd) public view returns (uint256) {
        address priceFeedAddress = s_priceFeed[_collaterTokenAddress];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        uint256 decimals = priceFeed.decimals();
        return (_usd * PRECISION) / (uint256(price) / (10 ** decimals));
    }

    function getCollateralBalanceInTokenAmount(address _collateralTokenAddress, address _user)
        external
        view
        returns (uint256)
    {
        return s_collateralDeposited[_user][_collateralTokenAddress];
    }

    function checkHealthFactor(uint256 _totalDscMinted, uint256 _collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _checkHealthFactor(_totalDscMinted, _collateralValueInUsd);
    }

    function getNumberOfMintedDsc(address _user) external view returns (uint256) {
        return s_dscMinted[_user];
    }

    function getCollateralTokens() external view returns(address[] memory){
        return s_collateralTokens;
    }

    function getUserCollateralAmount(address _tokenAddress,address _user)public view returns(uint256){
        return s_collateralDeposited[_user][_tokenAddress];
    }
    function getCollateralTokenPriceFeed(address _tokenAddress) public view returns(address) {
        return s_priceFeed[_tokenAddress];
        
    }

    // 50dsc => 150Dollers(1ETH).
    // 1ETH => 40 / under-collaterlaization
    // Maintain a threshhold where user should over-collateralized thier account
    // In our case more than 200% , which means having  50 dsc requires 101 usd worth of ETH.
    // when a user fails to liquidate for ex: having ETH which values around 80USD they are prone to
    // be liquidate by other users, means other user can buy paying the USD amount of dsc token that
    // prone to be liquidate, in our case 50 USD, Now they can have the ownership of the DSC.
    // and it's callateral base which 80USD worth of collateralization. now he have
}
