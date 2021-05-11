// 获取合约部署地址 abi

import { readFileSync } from "fs"

function getDeployedContractInfoByName(network: string, name: string) {
  // path.join()
  let fn = './deployments/artifacts/' + network + '/' + name + '.json'
  let data = readFileSync(fn, 'utf-8')
  let json = JSON.parse(data)
  return {address: json.address, abi: json.abi}
}

export default {
  getDeployedContractInfoByName,
}