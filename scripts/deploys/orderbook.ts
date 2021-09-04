import { deployOrderBook, deployOrderBookProxy } from '../../helpers/heco'
import { addressOf, TokenContractName } from '../../helpers/contractHelper';

;(async () => {
    const hre = require('hardhat')
        , proxy = true

    await deployOrderBook()
    if (proxy) {
        await deployOrderBookProxy()
    }
    
    const printContrct = (name: TokenContractName)  => { console.log("    '%s': '%s',", name, addressOf(name)) }
    console.log('\n')
    printContrct('OrderBook')
    if (proxy) {
        printContrct('OrderBookProxy')
        printContrct('OrderBookProxyAdmin')
    }
})()
