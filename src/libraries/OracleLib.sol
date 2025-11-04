// SPDX-License-Identifier-MIT

pragma solidity ^0.8.19;

import{AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {

    error OracleLib__stalePriceFeed();
    uint256 private constant TIME_LIMIT = 3 hours;
    function staleCheckLatestRoundData(AggregatorV3Interface _priceFeed) public view returns(uint80,int256,uint256,uint256,uint80){
          (uint80 roundId,int256 answer,uint256 startedAt,
          uint256 updatedAt,uint80 answeredInRound) =   _priceFeed.latestRoundData();
          uint256 secondsSince = block.timestamp - updatedAt;
          if(secondsSince > TIME_LIMIT){
            revert OracleLib__stalePriceFeed();
          }
          return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
    
} 