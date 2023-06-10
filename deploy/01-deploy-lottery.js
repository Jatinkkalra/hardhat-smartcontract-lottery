const { network, ethers } = require("hardhat");
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

const VRF_SUB_FUND_AMOUNT = ethers.utils.parseEther("2");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId; // Used here so that chainId of the selected development network is detected

  // Lottery Contract arguments
  let vrfCoordinatorV2Address, subscriptionId; //  Different for mocknet vs development chains
  const entranceFee = networkConfig[chainId]["entranceFee"];
  const gasLane = networkConfig[chainId]["gasLane"];
  const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"];
  const interval = networkConfig[chainId]["interval"];

  // Checking if we are deploying mocks or testnet, and acting accordingly
  if (developmentChains.includes(network.name)) {
    console.log("Local network detected (Mock)! Deploying Mocks....");
    // Now deploy a mock vrfCoordinatorV2. First fetch the mock contract address....
    const VRFCoordinatorV2Mock = await ethers.getContract(
      "VRFCoordinatorV2Mock"
    ); // Fetching mock contract
    vrfCoordinatorV2Address = VRFCoordinatorV2Mock.address; // Fetching address of mock contract

    // Automating the Fetching and Funding process for the SubscriptionId for mocknet
    const transactionResponse = await VRFCoordinatorV2Mock.createSubscription(); // function source: https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol
    const transactionReceipt = await transactionResponse.wait(1);
    subscriptionId = transactionReceipt.events[0].args.subId; // Assigning the subId argument of the first event to the variable
    // Funding the subscription
    await VRFCoordinatorV2Mock.fundSubscription(
      subscriptionId,
      VRF_SUB_FUND_AMOUNT
      /* fund amount */
    );
  } else {
    vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"]; // Fetching vrfCoordinatorV2 address of the selected network
    subscriptionId = networkConfig[chainId]["subscriptionId"];
  }

  // Deploying Lottery Contract
  const lottery = await deploy("Lottery", {
    from: deployer,
    args: [
      vrfCoordinatorV2Address,
      entranceFee,
      gasLane,
      subscriptionId,
      callbackGasLimit,
      interval,
    ],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  // Contract Verification
  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log("Verifying Contract........");
    await verify(lottery.address, args);
  }
  log("------------------------------------------");
};

module.exports.tags = ["all", "lottery"];
