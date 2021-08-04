import { assert } from "console"

const hre = require('hardhat')

const compoundAddress: { [index: string]: { [index: string]: string } } = {
    'heco': {},
    'hecotest': {
        'USDT': '0x04F535663110A392A6504839BEeD34E019FdB4E0',
        'WETH': '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836',
        'CETH': '0x78114ed51B179616Ea5F76913ebbCEad4625fc7E',
        'CTokenFactory': '0xbf7c839DFf6e849C742b33c676B2BfAF11a6a36c',
    }
}

function _getCompundAddress(contract: string) {
    let name = hre.network.name
        , addr = compoundAddress[name][contract]

    if (!addr) {
        throw new Error('not found contract address: ' + contract)
    }

    return addr
}

export function getWETH(): string {
    return _getCompundAddress('WETH')
}


export function getCTokenFactory() {
    return _getCompundAddress('CTokenFactory')
}

export function getCETH(): string {
    return _getCompundAddress('CETH')
}

// usdt address
export function getUSDT() {
    return _getCompundAddress('USDT')
}
