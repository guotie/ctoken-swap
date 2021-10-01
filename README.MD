# ctoken swap protocol

# why
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

### swap as mint

when user swap, they can got the platform token. Any pair can got platform token as long as the tokenA or tokenB can swap to the target token which is config by swap router.

## swap aggregator

swap aggregator, most focus on aggregator between cToken swap and token swap.

## Orderbook

limit orderbook. like swap LP, the maker's tokenA is deposit to compound/aave, mint to ctokenA, when the order is fulfiled, the taker receive tokenA which redeem from compound/aave, the maker get ctokenB, which if from the taker and deposit to compound/aave.

## token

debankex will mint `dToken` for every parters, include LP, lender, depositor.

