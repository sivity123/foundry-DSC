//SPDX-License-Identifier-MIT
pragma solidity ^0.8.18;

contract Invarient{

uint256 public s_shouldBeZero;
uint256 private s_hiddenValue;


function doStuff(uint256 _data)public{
    // if(_data == 2){
    //     s_shouldBeZero = 1;
    // }
    // if(s_hiddenValue == 7){
    //     s_shouldBeZero = 1;
    // }
    s_hiddenValue = _data;
}




}