import { assert } from "console"

const hre = require('hardhat')

export function getWETH(): string {
    let name = hre.network.name

    switch (name) {
        case 'heco':
            return ''

        case 'hecotest':
            return '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836'

        default:
            console.error('invalid network:', name)
            assert(false, 'invalid network')
            return ''
    }
}

// usdt address
export function getUSDT() {
    let name = hre.network.name

    switch (name) {
        case 'heco':
            return ''

        case 'hecotest':
            return '0x04F535663110A392A6504839BEeD34E019FdB4E0'

        default:
            console.error('invalid network:', name)
            assert(false, 'invalid network')
            return ''
    }
}