import { task } from 'hardhat/config';

import { flattenContract } from '../helpers/flatten'

task('deploy-orderbook', `Deploys the Orderbook contract`)
    .addFlag('verify', 'Verify Orderbook contract via Etherscan API.')
    .setAction(async ({ verify }, localBRE) => {

    })
