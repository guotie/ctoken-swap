# debankex protocol

## compound 

debankex protocol is like a bank, it reserve user's deposit, return interst to user, borrow coin to lenders.

## swap

debankex tread all swap liqudation as deposit, and LP will get the deposit intersts.

## Token

debankex will mint `dToken` for every parters, include LP, lender, depositor.


## todo

1. 手续费如何分?

只能等到这个块结束才能知道占比，因此，怎么分?

之前块的手续费累计起来，下一次集中发放

2. 杠杆借贷

totalCash, totalBorrow, totalSupply 均不变，只增加用户的代持合约的 balance
