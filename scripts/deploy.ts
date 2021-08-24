import { addressOf, TokenContractName } from '../helpers/contractHelper';
import {
    deployEbeHecoPool,
    deploySwap,
    deployOrderBook,
    deployStepSwap } from '../helpers/heco'

;(async () => {
    const hre = require('hardhat')
    
    // hre.network.name = 'hecotest'
    await deploySwap()
    await deployEbeHecoPool()
    await deployOrderBook()
    await deployStepSwap()

    const printContrct = (name: TokenContractName)  => { console.log('%s: %s', name, addressOf(name)) }
    printContrct('EBEToken')
    printContrct('Factory')
    printContrct('Router')
    printContrct('SwapExchangeRate')
    printContrct('HecoPool')
    printContrct('SwapMining')
    printContrct('OrderBook')
    printContrct('StepSwap')
})();
