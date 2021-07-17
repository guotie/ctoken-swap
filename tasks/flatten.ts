import { task } from 'hardhat/config';

import { flattenContract } from '../helpers/flatten'

task('flatten:all', `flatten contracts`)
    .setAction(async () => {
        // await flattenContract('Orderbook', './deploy/Orderbook.sol')
        // await flattenContract('Factory', './deploy/Factory.sol')
        // await flattenContract('Router', './deploy/Router.sol')
        // await flattenContract('StepSwap', './deploy/StepSwap.sol')
        console.log('flatten all')
    })
