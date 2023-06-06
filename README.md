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

# Setup:

## Extensions

- [Markdown All in One](https://marketplace.visualstudio.com/items?itemName=yzhang.markdown-all-in-one "Third-party Markdown extension")

## Console Commands

```js
yarn add --dev hardhat
yarn hardhat // create an empty hardhat.config.js
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
