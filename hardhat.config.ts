import 'dotenv/config';
import 'solidity-coverage';
import '@tenderly/hardhat-tenderly';
import 'hardhat-deploy';
import 'hardhat-local-networks-config-plugin';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import "@nomiclabs/hardhat-etherscan";
import "hardhat-deploy-ethers";

import { task } from 'hardhat/config';
// import { TASK_COMPILE } from 'hardhat/builtin-tasks/task-names';
// import overrideQueryFunctions from './lib/scripts/plugins/overrideQueryFunctions';

// task(TASK_COMPILE).setAction(overrideQueryFunctions);

task('seed', 'Add seed data').setAction(async (args, hre) => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const action = require('./lib/scripts/seeding/seedPools');
  await action(args, hre);
});

const CHAIN_IDS = {
  hardhat: 31337,
  kovan: 42,
  goerli: 5,
  mainnet: 1,
  rinkeby: 4,
  ropsten: 3,
  dockerParity: 17,
  hecotest: 256,
  heco: 128,
  bsc: 56,
};

const INFURA_KEY = process.env.INFURA_KEY || '';
const DEPLOYER_PRIVATE_KEY =
  process.env.DEPLOYER_PRIVATE_KEY || '0000000000000000000000000000000000000000000000000000000000000000';

const CONTROLLER_PRIVATE_KEY =
  process.env.CONTROLLER_PRIVATE_KEY || '0000000000000000000000000000000000000000000000000000000000000000';

export default {
  networks: {
    hardhat: {
      chainId: CHAIN_IDS.hardhat,
      saveDeployments: true,
      allowUnlimitedContractSize: true,
      mining: {
        auto: true,
        // interval: 0   // 使用 evm_mine 来手动挖矿
      }
    },
    dockerParity: {
      gas: 10000000,
      live: false,
      chainId: CHAIN_IDS.dockerParity,
      url: 'http://localhost:8545',
      saveDeployments: true,
    },
    hecotest: {
      chainId: CHAIN_IDS.hecotest,
      url: 'https://http-testnet.hecochain.com',
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`, `0x${CONTROLLER_PRIVATE_KEY}`],
      saveDeployments: true,
      allowUnlimitedContractSize: true,
    },
    heco: {
      chainId: CHAIN_IDS.heco,
      url: 'https://http-mainnet-node.huobichain.com',
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`, `0x${CONTROLLER_PRIVATE_KEY}`],
      saveDeployments: true,
    },
    mainnet: {
      chainId: CHAIN_IDS.mainnet,
      url: `https://mainnet.infura.io/v3/${INFURA_KEY}`,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`, `0x${CONTROLLER_PRIVATE_KEY}`], // Using private key instead of mnemonic for vanity deploy
      saveDeployments: true,
    },
    ropsten: {
      chainId: CHAIN_IDS.ropsten,
      url: `https://ropsten.infura.io/v3/${INFURA_KEY}`,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`, `0x${CONTROLLER_PRIVATE_KEY}`], // Using private key instead of mnemonic for vanity deploy
      saveDeployments: true,
    },
    kovan: {
      chainId: CHAIN_IDS.kovan,
      url: `https://kovan.infura.io/v3/${INFURA_KEY}`,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`, `0x${CONTROLLER_PRIVATE_KEY}`], // Using private key instead of mnemonic for vanity deploy
      saveDeployments: true,
    },
    rinkeby: {
      chainId: CHAIN_IDS.rinkeby,
      url: `https://rinkeby.infura.io/v3/${INFURA_KEY}`,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`, `0x${CONTROLLER_PRIVATE_KEY}`], // Using private key instead of mnemonic for vanity deploy
      saveDeployments: true,
    },
    goerli: {
      chainId: CHAIN_IDS.goerli,
      url: `https://goerli.infura.io/v3/${INFURA_KEY}`,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`, `0x${CONTROLLER_PRIVATE_KEY}`], // Using private key instead of mnemonic for vanity deploy
      saveDeployments: true,
    },
    bsc: {
      chainId: CHAIN_IDS.bsc,
      url: `https://bsc-dataseed1.binance.org`,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`, `0x${CONTROLLER_PRIVATE_KEY}`], // Using private key instead of mnemonic for vanity deploy
      saveDeployments: true,
    }
  },
  namedAccounts: {
    deployer: {
      default: 0,
      [CHAIN_IDS.mainnet]: 0,
      [CHAIN_IDS.kovan]: 0,
      [CHAIN_IDS.ropsten]: 0,
      [CHAIN_IDS.goerli]: 0,
      [CHAIN_IDS.rinkeby]: 0,
      [CHAIN_IDS.dockerParity]: 0,
      [CHAIN_IDS.hecotest]: 0,
      [CHAIN_IDS.heco]: 0,
    },
    admin: {
      default: 1, // here this will by default take the first account as deployer
      // We use explicit chain IDs so that export-all works correctly: https://github.com/wighawag/hardhat-deploy#options-2
      [CHAIN_IDS.mainnet]: '0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f',
      [CHAIN_IDS.kovan]: 1,
      [CHAIN_IDS.ropsten]: 1,
      [CHAIN_IDS.goerli]: 1,
      [CHAIN_IDS.rinkeby]: '0x44DDF1D6292F36B25230a72aBdc7159D37d317Cf',
      [CHAIN_IDS.dockerParity]: 1,
      [CHAIN_IDS.hecotest]: 1,
      [CHAIN_IDS.heco]: 1,
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.5.16',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      }, {
        version: '0.6.12',
        settings: {
          optimizer: {
            enabled: true,
            runs: 999,
          },
        },
      }, {
        version: '0.7.6',
        settings: {
          optimizer: {
            enabled: true,
            runs: 999,
          },
        },
      }
    ],
    overrides: {
      // 'contracts/compound/lp/Chef.sol': {
      //   version: '0.6.12',
      // },
      // 'contracts/compound/lp/IMdexPair.sol': {
      //   version: '0.6.12',
      // },
      // 'contracts/compound/dao/Dao.sol': {
      //   version: '0.7.2',
      // },
      // '@openzeppelin/contracts/*/*': {
      //   version: '0.7.2',
      // },
    },
  },
  tenderly: {
    username: 'balancer',
    project: 'v2',
  },
  paths: {
    deploy: 'deployments/migrations',
    deployments: 'deployments/artifacts',
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};
