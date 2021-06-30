import { deployAll } from "../deployments/deploys";
const hre = require('hardhat')

hre.network.name = 'hecotest'

deployAll({}, true)
