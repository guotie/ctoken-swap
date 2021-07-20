import { _deploy } from "./deploys";

// deploy swap factory
export async function deployRouter(
                _factory: string,
                _wht: string,
                _cwht: string,
                _ctokenFactory: string
            ) {

}

// deploy swap factory
export async function deployFactory() {

}

// 部署 OrderBook
export async function deployOrderBook(
                ctokenFactory: string,
                _ceth: string,
                _weth: string,
                _margin: string,
                deployer: string,
                verify: boolean
            ) {
    let l = await _deploy('OBPriceLogic', {
            from: deployer,
            args: [],
            log: true,
        },
        false
    )
    let c = await _deploy('OBPairConfig', {
            from: deployer,
            args: [],
            log: true,
        },
        false
    )

    console.log('deploy OBPriceLogic at:', l.address)

    return _deploy('OrderBook', {
            from: deployer,
            args: [ctokenFactory, _ceth, _weth, _margin],
            libraries: {
                OBPriceLogic: l.address,
                OBPairConfig: c.address
            },
            log: true,
        }, verify
    );
}