// Notes:
// Initial code is same as "./01-deploy-lottery.js", except the args

const { log } = require("ethers");
const { network } = require("hardhat");

const { developmentChains } = require("../helper-hardhat-config"); // helpful for mock chain recognition and deployment

const BASE_FEE = ethers.utils.parseEther("0.25"); // 0.25 LINK is the cost for each request (https://docs.chain.link/vrf/v2/subscription/supported-networks#sepolia-testnet)
const GAS_PRICE_LINK = 1e9; // aka 1_000_000_000 // Link per gas || A calculated value based on gas price of the chain, which changes constantly.

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  if (developmentChains.includes(network.name)) {
    console.log("Local network detected (Mock)! Deploying Mocks....");
    // Now deploy a mock vrfCoordinatorV2....
    await deploy("VRFCoordinatorV2Mock", {
      from: deployer,
      log: true,
      args: [BASE_FEE, GAS_PRICE_LINK], // args taken from the constructor of Chainlink's VRFCoordinatorV2Mock.sol
      waitConfirmations: network.config.blockConfirmations || 1,
    });

    log("Mocks Deployed!");
    console.log("---------------------------------");
  }
};

module.exports.tags = ["all", "mocks"];
