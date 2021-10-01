# 根据产生的手续费给 LP 分成


# 各个交易对分配代币

router中保存所有的交易对的手续费: allPairFee

在每个交易对中保存中交易费, 上次结算交易费, 上次结算总交易费
pairFee
pairFeeLast
allPairFeeLast
lastBlock
currentBlock: 当前块
rewardPerBlock: 每块奖励

则本次结算应分配的代币数量为:
占比 = (pairFee-pairFeeLast) / (allPairFee-allPairFeeLast)
总奖励 = 占比 * rewardPerBlock * (currentBlock - lastBlock)

LP分配：
LP:
rewardDebt: = mint时 LP/总LP * 总奖励
