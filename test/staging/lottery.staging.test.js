// Objective:
// To run tests on a staging/testnet network using Chainlink VRF interface:
// 1. Get our SubId for Chainlink VRF, Fund it and update "../helper-hardhat.config.js".    // SubId: 1604 (Source: https://vrf.chain.link/)
// 2. Deploy our contract using SubId.  // `yarn hardhat deploy --network sepolia`
// 3. Register the contract & it's SudId with Chainlink VRF.    // Add consumer here: https://vrf.chain.link/
// 4. Register the contract with Chainlink Keepers.     // Register new Upkeep here: https://keepers.chain.link/; Starting balance (LINK): 8
// 5. Run staging tests // Can be done via etherscan(Write Contract), a deploy script (https://github.com/PatrickAlphaC/hardhat-smartcontract-lottery-fcc/blob/main/scripts/enter.js) or via console(`yarn hardhat test --network sepolia`)

const { getNamedAccounts, deployments, network, ethers } = require("hardhat");
const {
  developmentChains,
  networkConfig,
} = require("../../helper-hardhat-config");
const { assert, expect } = require("chai");

developmentChains.includes(network.name)
  ? describe.skip
  : describe("Lottery Staging Test", function () {
      let deployer,
        lottery,
        lotteryEntranceFee; /* , vrfCoordinatorV2Mock , interval; */ // Not needed on actual testnet chains ;
      /* const chainId = network.config.chainId */ // Not needed on actual testnet chains

      beforeEach(async function () {
        deployer = (await getNamedAccounts()).deployer;
        /* await deployments.fixture(["all"]); */ // bcoz running the deploy scripts will deploy the contract already
        lottery = await ethers.getContract("Lottery", deployer);
        /* vrfCoordinatorV2Mock = await ethers.getContract(
          "VRFCoordinatorV2Mock",
          deployer
        ); */
        lotteryEntranceFee = await lottery.getEntranceFee();
        /* interval = await lottery.getInterval(); */
      });

      // Test: fullfillRandomWords function
      describe("fulfillRandomWords", function () {
        it("works with live Chainlink Keepers and Chainlink VRF, we get a random winner", async function () {
          // setup a listener before entering the lottery, just in case the blockchain moves really fast

          const startingTimeStamp = await lottery.getLatestTimeStamp();
          const accounts = await ethers.getSigners();

          // listener
          await new Promise(async (resolve, reject) => {
            lottery.once("WinnerPicked", async () => {
              console.log("WinnerPicked event fired!");
              // Doing the asserts only after the winner is picked
              try {
                // asserts here:
                const recentWinner = await lottery.getRecentWinner();
                const lotteryState = await lottery.getLotteryState();
                const winnerEndingBalance = await accounts[0].getBalance();
                const endingTimeStamp = await lottery.getLatestTimeStamp();

                await expect(lottery.getPlayers(0)).to.be.reverted; // checking if lottery has been resetted as there won't be anything at 0 index. Use assert if this is confusing.
                assert.equal(recentWinner.toString(), accounts[0].address); // players array has been reset
                assert.equal(lotteryState, 0); // state is OPEN
                assert.equal(
                  winnerEndingBalance.toString(),
                  winnerStartingBalance.add(lotteryEntranceFee).toString()
                ); // money has been sent to winner
                assert(endingTimeStamp > startingTimeStamp);

                resolve();
              } catch (error) {
                console.log(error);
                reject(e);
              }
            });
            // enter the raffle
            await lottery.enterLottery({ value: lotteryEntranceFee }); // this code wont finish until the listener has finished listening
            const winnerStartingBalance = await accounts[0].getBalance(); // Fetching the winner's starting balance
          });
        });
      });
    });
