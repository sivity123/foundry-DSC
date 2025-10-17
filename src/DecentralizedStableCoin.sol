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

// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20//extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title - Denctralize stableCoin
 * @author - Sivanesh Sakthivel
 * @notice - This StableCoin will minted thorugh algrothimically by governing DSCEngine.sol
 * @notice -  Relative Stability , pegged/Anchered to USD.(non-fiat)
 * @notice - Stablility method, Algorithmic.(Decentralized without any human intervention).
 * @notice - collaterlization with Crypto's(ETH&BTC),expects over-collateralization to tackle
 * volatility this crypto.
 */

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    /* ERRORS */
    error DecentralizedStableCoin__BurnValueExceedsUserBalance();
    error DecentralizedStableCoin__ExpectsMoreThanZeroValue();
    error DecentralizedStableCoin__MustBeANonZeroAddress();

    /* state variables */
    //constants
    uint256 private constant INITIAL_TOKEN_SUPPLY = 188;

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _value) public override onlyOwner {//still owner cannot burn the user value directly 
        uint256 balance = balanceOf(msg.sender);
        if (balance < _value) {
            revert DecentralizedStableCoin__BurnValueExceedsUserBalance();
        }
        if (_value <= 0) {
            revert DecentralizedStableCoin__ExpectsMoreThanZeroValue();
        }
        super.burn(_value);
    }

    function mint(address _to,uint256 _value) external onlyOwner returns(bool){
        if(_to == address(0)){
            revert DecentralizedStableCoin__MustBeANonZeroAddress();
        }
        if(_value <= 0){
            revert DecentralizedStableCoin__ExpectsMoreThanZeroValue();
        }
        _mint(_to,_value);
        return true;
    }


}








