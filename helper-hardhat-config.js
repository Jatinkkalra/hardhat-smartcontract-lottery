// Notes:
// Mostly boiler plate.

const { ethers } = require("hardhat");

const networkConfig = {
  11155111: {
    name: sepolia,
    vrfCoordinatorV2: 0x8103b0a8a00be2ddc778e6e7eaa21791cd364625, // ".lottery.sol" constructor args from here  // Address fetched from: https://docs.chain.link/vrf/v2/subscription/supported-networks#sepolia-testnet
    entranceFee: ethers.utils.parseEther("0.01"),
    gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // gasLane aka 30 gwei Key Hash fetched from: https://docs.chain.link/vrf/v2/subscription/supported-networks#sepolia-testnet
    subscriptionId: "0", // to be updated later
    callbackGasLimit: "500_000", //500K gas limit
    interval: "30", // 30 seconds
  },
  31337: {
    name: "hardhat",
    // vrfCoordinatorV2: // Not needed as mocks will be used
    entranceFee: ethers.utils.parseEther("0.01"),
    gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // Anything here. Mocks will be used anyway
    callbackGasLimit: "500_000", //500K gas limit
    interval: "30", // 30 seconds
  },
};

const developmentChains = ["hardhat", "localhost"]; // helpful for mock chain recognition and deployment

module.exports = { networkConfig, developmentChains };
