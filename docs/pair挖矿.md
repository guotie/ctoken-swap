当用户把币存入swap pair交易对时，实际上存入的是ctoken，如果ctoken存款有挖矿的话，那么挖矿的收益是pair合约拿到了。

如何把pair合约拿到的挖矿收益分配给LP用户？

# LP 提供流动性得到的平台币

1. pair 待分配平台币手续费

pairEBE = (pair未分配手续费) * 待分配平台币 / (平台未分配总手续费) = (pair.currentFee()) * 待分配平台币 / (router.swapFeeCurrent())

待分配平台币 = router当前平台币 + 待挖平台币 = router.ebeRewards()  + router.pendingEBE();

2. 用户 LP 得到的平台币手续费

用户 LP数量 * pair待分配平台币 / totalSupply
