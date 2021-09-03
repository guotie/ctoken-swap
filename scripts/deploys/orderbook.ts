import { deployOrderBook, deployOrderBookProxy } from '../../helpers/heco'

;(async () => {
    const hre = require('hardhat')

    await deployOrderBook()
    // await deployOrderBookProxy()
})()
