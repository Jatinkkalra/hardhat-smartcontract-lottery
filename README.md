# Smart Contract Lottery [Hardhat - Backend]

## Table Of Content

- [Setup:](#setup)
  - [Extensions](#extensions)
  - [Console Commands](#console-commands)
  - [Create Folders and Files](#create-folders-and-files)
  - [Command Prompts:](#command-prompts)
  - [Import:](#import)
- [Notes](#notes)
- [Tests](#tests)
  - [Staging Test](#staging-test)

# Objective

## Contracts

### lottery.sol

1. Enter the lottery (paying some amount)
2. Pick a random winner (verifiably random) (Winner to be selected once a parameter is satisfied. Eg: time, asset price, money in liquidity pool etc)
3. Completely automated winner selection
   > The following should be true in order to return true:
   >
   > 1. Our time internal should have passed
   > 2. The lottery should have atleast 1 player, and have some ETH
   > 3. Our subscription is funded with LINK
   > 4. The lottery should be in an "open" state.

#### Steps:

1. Objective 1/3: Enter the Lottery: enterLottery() Function

   - Set minimum amount to enter (immutable variable, set on contract creation via constructor) // get function: getEntranceFee()
   - Create array of addresses entered // get function: getPlayer(uint256 index)
   - Event declaration

2. Objective 2/3: Pick a random winner

   - To pick a random number, a 2 transaction process:
     - Request a random number (1/2): requestRandomWinner() Function (renamed to performUpkeep())
     - Once requested, do something with it (2/2): fulfillRandomWords() Function
       - Pick a random winner // getRecentWinner()
       - Send the money
       - Keep the list of all winners // emit indexed events WinnerPicked(recentWinner) // (outside the contract, in the logs. As there is no array of winners written yet)
       - Resetting the entries array, and timestamp
   - Event declaration

3. Objective (3/3: Completely automated winner selection)
   - checkUpkeep
   - performUpkeep
   - Event declaration

## Deploy Scripts

### 00-deploy-mocks.js

#### Steps:

As constructor of lottery.sol consists a contract "vrfCoordinatorV2" which is outside of our contract, we are going to deploy some mocks for this.

### 01-deploy-lottery.js

#### Steps:

- modify hardhat.config.js
- create .env file
- create "helper.hardhat.config": Used to deploy mocks if we are on development chain, and actual contract address if we are on testnet or mainnet.
  - Configure network and parameter details
- create "0-deploy-mocks.js" to deploy the mock when not on any development chain (localhost, testnet or mainnet)
- create "test" folder and "VRFCoordinatorV2Mock.sol" file. Import VRFCoordinatorV2Mock: https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol

# Setup:

Here I have kept my personal notes on the setup process. Only for personal reference purpose.

## Extensions

- [Markdown All in One](https://marketplace.visualstudio.com/items?itemName=yzhang.markdown-all-in-one "Third-party Markdown extension")

## Console Commands

```js
yarn add --dev hardhat  // Creates node modules, package.json and yarn.lock files
yarn hardhat // choose "create an empty hardhat.config.js" wgich creates hardhat.config.js file
yarn add --dev @nomiclabs/hardhat-ethers@npm:hardhat-deploy-ethers ethers @nomiclabs/hardhat-etherscan @nomiclabs/hardhat-waffle chai ethereum-waffle hardhat hardhat-contract-sizer hardhat-deploy hardhat-gas-reporter prettier prettier-plugin-solidity solhint solidity-coverage dotenv // upto the dev to choose the tools/dependencies
yarn add --dev @chainlink/contracts // for importing purpose.
yarn add global hardhat-shorthand   // for hardhat shortform and autocompletion
```

## Create Folders and Files

- "./.prettierrc"
- "contracts" folder

  - "./lottery.sol" file
  - "test" folder
    - "./VRFCoordinatorV2Mock.sol" file

- "deploy" folder
  - "00-deploy-mocks.js" file
  - "./01-deploy-lottery.js" file
  - 99-update-front-end.js
- .env
- "helper-hardhat-config.js"
- "utils" folder
  - "./verify.js" file
- "test" folder
  - "unit" folder
    - "Lottery.test.js" file
  - "staging" folder
    - "lottery.staging.test.js"
- ".gitignore" file

> _**Note**: Rest folders/files will be automatically created by the dependencies._

## Command Prompts:

- `yarn hardhat compile`

  > After basic setup of "./lottery.sol". _This creates artifacts and cache folder._

## Import:

```js
- import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol"; // importing for chainlink varifiable randomness scripts
- import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol"; // importing interface
```

# Tests

- Ideally we make our tests have just 1 assert per "it"
- empty bytes data = "0x"
- describe functions can't recognise promises by itself. Thus there is no need to make it async at the beginning.
  Instead, `it` will use the async functions.

## Staging Test

1. Get our SubId for Chainlink VRF.
2. Deploy our contract using SubId.
3. Register the contract with Chainlink VRF & it's SudId.
4. Register the contract with Chainlink Keepers.
5. Run staging tests

# Notes

- Events naming convention: Function name reversed
- External functions are bit cheaper as they are not called by own contract
- ./hardhat.config.js" file needs to import the dependencies mentioned in "./package.json" to configure the hardhat features/settings.

- To pick a random number, a 2 transaction process:

  - Request a random number (1/2);
  - Once requested, do something with it (2/2)

- Hardhat shorthand is an NPM package that autocompletes few commands while using shortforms

  > Eg: `yarn hardhat compile` and `hh compile` both are same now

- Usage of enum, block.timestamp, chainlink's checkUpKeep & performUpKeep
- Types of variables (s_Storage, i_Immutable, CONSTANT):

  - Storage Variables can be modified.
  - Constant variables are always fixed for each contract.
  - Immutable variables are set via constructor during the contract creation.

- Visibility (Public, Private, External, Internal)

- Enums:
  Enums in Solidity are used to create custom data types with a finite set of possible values. Each value in the enum is represented by an integer, starting from 0 for the first value and incrementing by 1 for subsequent values.
  They provide a more expressive and readable way to work with such values compared to using plain integers or strings.

# References

- requestRandomWords (in performUpkeep()): https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol
- fulfillRandomWords() : https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol
- Automation via Chainlink Keeper (checkUpkeep / performUpkeep): https://docs.chain.link/chainlink-automation/compatible-contracts
