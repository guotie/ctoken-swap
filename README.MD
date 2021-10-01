# ctoken swap protocol

## why
To prompt user's APY, they can deposit their token in compound/aave, and in the same time, provide liquidity to get swap fee.

## swap

swap protocol is just like uniswap, AMM protocol. The most differece is in this swap, pair's token0 and token1 is cToken. so, the user can have 3 benefit:
* first, as LP, they will get swap fee;
* second, their token is deposit in compound/aave, so they can get interest and COMP/AAVE token;
* the platform token

### Add Liquidity

when user add liquidity, their token will transfer to compound/aave pool to mint to cToken/aToken.

### swap

when some user swap, there are two sceno:

* first, swap cToken/aToken direct
In this sceno, it just like uniswap

* second, swap tokens
In this sceno, we will redeem token from compound/aave, then transfer to swaper

### Remove Liquidity

when LP remove their liquidity, they will get:
* LP fee
* interests from compound/aave
* COMP/AAVE tokens
* our platform tokens

## Token

debankex will mint `dToken` for every parters, include LP, lender, depositor.

