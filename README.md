# Pegged or Anchered StabilCoin
1) Our stableCoin will be pegged to $1.00(usd).(Relative stability)
   1) We use chainlink price feeds 
   2) set a function to exachange ETH & BTC 

2) We are going to make this stablecoin minting and burning through algorithmic.(stablity method)
    1) Controlling minting algorthimically(no human intevention),user with enough collateral(or even over-collateral) can only mint tokens.(will be coded on chain)
3) This stableCoin will be backed with exogenous collateral as base with crypto.(Collateral Type)
    1) ETH
    2) BTC

irresolved Bugs:
1) _healthFactor function get the ration comparing with minted Dsc, if DSC is 0, it will revert with divsion by zero panic error.