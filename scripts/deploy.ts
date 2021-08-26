import { addressOf, TokenContractName } from '../helpers/contractHelper';
import {
    deployEbeHecoPool,
    deploySwap,
    deployOrderBook,
    deployStepSwap,
    doSettings } from '../helpers/heco'

// hecotest 部署时, 报错：
// deploy contracts/flatten/Factory.sol:DeBankFactory failed: Error: ENOENT: no such file or directory, open '/root/debankex/deployments/artifacts/hecotest/contracts/flatten/Factory.sol:DeBankFactory.json'
//     at Object.openSync (fs.js:498:3)
//     at Object.writeFileSync (fs.js:1524:35)
//     at DeploymentsManager.saveDeployment (/root/debankex/node_modules/hardhat-deploy/src/DeploymentsManager.ts:757:10) {
//   errno: -2,
//   syscall: 'open',
//   code: 'ENOENT',
//   path: '/root/debankex/deployments/artifacts/hecotest/contracts/flatten/Factory.sol:DeBankFactory.json'
// }
// (node:20046) UnhandledPromiseRejectionWarning: TypeError: Cannot read property 'address' of undefined
//     at Object.<anonymous> (/root/debankex/helpers/heco.ts:50:43)
//     at step (/root/debankex/helpers/heco.ts:33:23)
//     at Object.next (/root/debankex/helpers/heco.ts:14:53)
//     at fulfilled (/root/debankex/helpers/heco.ts:5:58)
// (Use `node --trace-warnings ...` to show where the warning was created)
//
// 解决方案:
// cp -r artifacts/contracts deployments/artifacts/hecotest/

;(async () => {
    // const hre = require('hardhat')
    
    // hre.network.name = 'hecotest'
    await deploySwap()
    await deployEbeHecoPool()
    await deployOrderBook()
    await deployStepSwap()

    await doSettings()

    const printContrct = (name: TokenContractName)  => { console.log("    '%s': '%s',", name, addressOf(name)) }
    printContrct('EBEToken')
    printContrct('Factory')
    printContrct('Router')
    printContrct('SwapExchangeRate')
    printContrct('HecoPool')
    printContrct('SwapMining')
    printContrct('OrderBook')
    printContrct('StepSwap')

    console.info('\n--------------------------------compelete--------------------------------\n')
})();
