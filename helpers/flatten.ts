// import { Contract } from 'ethers/lib/ethers';

import { writeFileSync } from "fs";

// import { HardhatRuntimeEnvironment } from 'hardhat/types';
const hre = require('hardhat')

const TASK_FLATTEN_GET_FLATTENED_SOURCE = 'flatten:get-flattened-sources';
const TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS = 'compile:solidity:get-source-paths';

const SOLIDITY_PRAGMA = 'pragma solidity';
const LICENSE_IDENTIFIER = 'License-Identifier';
const EXPERIMENTAL_ABIENCODER = 'pragma experimental ABIEncoderV2;';


// const encodeDeployParams = (instance: Contract, args: (string | string[])[]) => {
//   return instance.interface.encodeDeploy(args).replace('0x', '');
// };

// Remove lines at "text" that includes "matcher" string, but keeping first "keep" lines
const removeLines = (text: string, matcher: string, keep = 0): string => {
  let counter = keep;
  return text
    .split('\n')
    .filter((line) => {
      const match = !line.includes(matcher);
      if (match === false && counter > 0) {
        counter--;
        return true;
      }
      return match;
    })
    .join('\n');
};

// Try to find the path of a Contract by name of the file without ".sol"
const findPath = async (id: string): Promise<string> => {
  const paths = await hre.run(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS);
  // console.log('paths:', paths)
  const path = paths.find((x: string) => {
    let t = x.split('/');
    t = t[t.length - 1].split('\\')
    // console.log('t:', t)
    return t[t.length - 1].split('.')[0] == id;
  });

  if (!path) {
    throw Error('Missing path for contract name: ${id}');
  }

  return path;
};

// Hardhat Flattener, similar to truffle flattener
const hardhatFlattener = async (filePath: string) =>
  await hre.run(TASK_FLATTEN_GET_FLATTENED_SOURCE, { files: [filePath] });

// Verify a smart contract at Polygon Matic network via a GET request to the block explorer
export const flattenContract = async (
  id: string,
  to: string
  // instance: Contract,
  // args: (string | string[])[]
) => {
  /*
    ${net == mumbai or mainnet}
    https://explorer-${net}.maticvigil.com/api
    ?module=contract
    &action=verify
    &addressHash={addressHash}
    &name={name}
    &compilerVersion={compilerVersion}
    &optimization={false}
    &contractSourceCode={contractSourceCode}
  */
  // const network = (DRE as HardhatRuntimeEnvironment).network.name;
  // const net = network === EthereumNetworkNames.matic ? 'mainnet' : network;
  const filePath = await findPath(id);
  // const encodedConstructorParams = encodeDeployParams(instance, args);
  const flattenSourceCode = await hardhatFlattener(filePath);

  // Remove pragmas and license identifier after first match, required by block explorers like explorer-mainnet.maticgivil.com or Etherscan
  const cleanedSourceCode = removeLines(
    removeLines(removeLines(flattenSourceCode, LICENSE_IDENTIFIER, 1), SOLIDITY_PRAGMA, 1),
    EXPERIMENTAL_ABIENCODER,
    1
  );

  writeFileSync(to, cleanedSourceCode)
  return cleanedSourceCode
    // console.log(cleanedSourceCode)
};
