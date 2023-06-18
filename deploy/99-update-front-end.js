// Objective
// Writing a script which is connected to our front-end and makes it responsive and "constants" folder of frontend gets updated with chain switch

const { ethers, network } = require("hardhat");
const fs = require("fs");

const FRONT_END_ADDRESSES_FILE =
  "../nextjs-smartcontract-lottery-npx/constants/contractAddresses.json";
const FRONT_END_ABI_FILE =
  "../nextjs-smartcontract-lottery-npx/constants/abi.json";

module.exports = async function () {
  if (process.env.UPDATE_FRONT_END) {
    console.log("Updating front end...");
    updateContractAddresses();
    updateAbi();
  }
};

async function updateContractAddresses() {
  const lottery = await ethers.getContract("Lottery");
  const chainId = network.config.chainId.toString();

  const currentAddresses = JSON.parse(
    fs.readFileSync(FRONT_END_ADDRESSES_FILE, "utf8")
  ); // Reads the content of the frontend addresses file and assigns it to `currentAddresses` variable

  if (chainId in currentAddresses) {
    if (!currentAddresses[chainId].includes(lottery.address)) {
      currentAddresses[chainId].push(lottery.address);
    } // adding chainId(key) and address(value) if not already mentioned in frontend [mapping is used]
  }
  {
    currentAddresses[chainId] = [lottery.address]; // if chainId doesn't even exist, it will be added
  }
  fs.writeFileSync(FRONT_END_ADDRESSES_FILE, JSON.stringify(currentAddresses)); //  the updated `currentAddresses` object is written back to the frontend addresses file, overwriting the previous content of the file.
}

async function updateAbi() {
  const lottery = await ethers.getContract("Lottery");
  fs.writeFileSync(
    FRONT_END_ABI_FILE,
    lottery.interface.format(ethers.utils.FormatTypes.json)
  );
}

module.exports.tags = ["all", "frontend"];
