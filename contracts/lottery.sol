// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Objective:
// 1. Enter the lottery (paying some amount)
// 2. Pick a random winner (verifiably random) (Winner to be selected once a parameter is satisfied. Eg: time, asset price, money in liquidity pool etc)
// 3. Completely automated winner selection:
//  * The following should be true in order to return true:
//  * i. Our time internal should have passed
//  * ii. The lottery should have atleast 1 player, and have some ETH
//  * iii. Our subscription is funded with LINK
//  * iv. The lottery should be in an "open" state.

// As we are picking random winner (2) and we have some event driven execution (3), we will use Chainlink Oracles
// Aka Chainlink Oracles for Randomness and Automated Execution (ie Chainlink Keepers)

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol"; // for checkUpkeep and performUpkeep

error Lottery__NotEnoughETHEntered();
error Lottery__WinnerTransferFailed();
error Lottery__NotOpen();
error Lottery__checkUpkeepFalse(
  uint256 currentBalance,
  uint256 numPlayers,
  uint256 lotteryState,
  uint256 interval
);

/**
 * @title A sample lottery contract
 * @author Jatin Kalra
 * @notice A contract for creating an untamperable decentralised smart contract
 * @dev This implements Chainlink VRF V2 & Chainlink Keepers
 */

contract Lottery is
  VRFConsumerBaseV2 /* Inheritance to override the fullfillRandomWords internal function from "./node_modules" */,
  KeeperCompatibleInterface /* for checkUpkeep and performUpkeep functions */
{
  // Type Declaration
  enum LotteryState {
    OPEN,
    CALCULATING
  } // in background (indexed): uint256 0 = OPEN, 1 = CALCULATING

  // State Variables
  uint256 private immutable i_entranceFee; // minimum price // A storage var
  address payable[] private s_players; // array of addresses entered (1/2) // payable addresses as if one of them wins, we would be paying them
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator; // this is a contract
  bytes32 private immutable i_gasLane;
  uint64 private immutable i_subscriptionId;
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private immutable i_callbackGasLimit;
  uint32 private constant NUM_WORDS = 1;

  // Lottery Variables (new section for state variables)
  address private s_recentWinner;
  LotteryState private s_lotteryState; // To keep track of contract status (OPEN, CALCULATING) // Other method: uint256 private s_state;
  uint256 private s_lastTimeStamp; // To keep track of block.timestamps
  uint256 private immutable i_interval; // interval between each winner

  // Events
  event LotteryEnter(address indexed player);
  event RequestedLotteryWinner(uint256 indexed requestId);
  event WinnerPicked(address indexed winner);

  // Functions
  /**
   * @notice Constructs a new Lottery contract with the parameters set here.
   * @param vrfCoordinatorV2 The address of the VRFCoordinatorV2 contract.
   * @param entranceFee The minimum price required to enter the lottery.
   * @param gasLane The unique identifier (keyHash) for the VRF system to generate random numbers. Max gas price.
   * @param subscriptionId The unique subscription ID used for funding VRF requests.
   * @param callbackGasLimit The gas limit for the callback request to fulfill the random number.
   * @param interval The interval between each winner selection.
   */
  constructor(
    address vrfCoordinatorV2, // contract address
    uint256 entranceFee,
    bytes32 gasLane /* or keyHash */,
    uint64 subscriptionId,
    uint32 callbackGasLimit,
    uint256 interval
  ) VRFConsumerBaseV2(vrfCoordinatorV2) {
    i_entranceFee = entranceFee;
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
    i_gasLane = gasLane;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;
    s_lotteryState = LotteryState.OPEN;
    s_lastTimeStamp = block.timestamp;
    i_interval = interval;
  }

  // Objective (1/3: Enter the lottery)

  /**
   * @notice Allows a participant to enter the lottery by paying the entrance fee.
   * @dev Participants must send an amount of Ether greater than or equal to the entrance fee.
   * @dev The lottery must be in an "open" state to allow entries.
   * @dev Emits the `LotteryEnter` event when a participant successfully enters the lottery.
   * @dev Throws a `Lottery__NotEnoughETHEntered` error if the participant does not send enough Ether.
   * @dev Throws a `Lottery__NotOpen` error if the lottery is not in an "open" state.
   */
  function enterLottery() public payable {
    // Other method: require (msg.value > i_entranceFee, "Not Enough ETH!") // gas costly as string is stored as error
    // gas efficient mehod below as error code is stored
    if (msg.value < i_entranceFee) {
      revert Lottery__NotEnoughETHEntered();
    }
    if (s_lotteryState != LotteryState.OPEN) {
      revert Lottery__NotOpen();
    }
    s_players.push(payable(msg.sender)); // array of addresses entered (2/2)

    // Emit an Event whenever we update a dynamic array or mapping; More gas-efficient than storing the variable as thet are stored outside the smart contract
    emit LotteryEnter(msg.sender);
  }

  // Objective (3/3: Completely automated)

  /**
   * @notice Checks if it's time to select a new random winner and restart the lottery.
   * @dev This function is called by Chainlink Keepers nodes to determine if the upkeep is true.
   * @dev The following conditions must be true to return `true`:
   *   i. time interval should have passed.
   *   ii. The lottery should have at least 1 player and have some ETH.
   *   iii. Our subscription is funded with LINK.
   *   iv. The lottery should be in an "open" state.
   * @dev checkUpkeep and performUpkeep reference: https://docs.chain.link/chainlink-automation/compatible-contracts
   * @return upkeepNeeded True if the conditions for selecting a new random winner are met, false otherwise.
   */
  function checkUpkeep(
    bytes memory /* checkData */
  ) public override returns (bool upkeepNeeded, bytes memory /*performData*/) {
    // changed from external to public so that performUpkeep can call it to verify
    //  iv. The lottery should be in an "open" state.
    bool isOpen = (LotteryState.OPEN == s_lotteryState);

    // i. Our time internal should have passed (ie: (current block.timestamp - last block.timestamp) > winner interval)
    bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);

    //  ii. The lottery should have atleast 1 player, and have some ETH
    bool hasPlayers = (s_players.length > 0);
    bool hasBalance = (address(this).balance > 0);

    //  iii. Our subscription is funded with LINK

    // Checking if all booleans are true or not, in order to restart lottery
    upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
  } // Formating source: https://docs.chain.link/chainlink-automation/compatible-contracts

  // Objective (2/3: Pick a random winner)
  // To pick a random number, a 2 transaction process: Request a random number (1/2); Once requested, do something with it (2/2)
  // Request a random number (1/2)

  /**
   * @notice Performs the upkeep and selects a new random winner for the lottery.
   * @dev This function is called by Chainlink Keepers when the conditions for selecting a new winner are met.
   * @dev Throws a `Lottery__checkUpkeepFalse` error if the conditions for selecting a new winner are not met.
   * @dev Emits the `RequestedLotteryWinner` event when a new winner is requested.
   */
  function performUpkeep(bytes calldata /*performData*/) external {
    //external function as it saves gas when called outside of this contract
    (bool upkeepNeeded, ) = checkUpkeep(""); // checking if checkUpKeep is true
    if (!upkeepNeeded) {
      revert Lottery__checkUpkeepFalse(
        address(this).balance,
        s_players.length,
        uint256(s_lotteryState),
        i_interval
      ); // relevant paramaters status to know why it failed
    }

    s_lotteryState = LotteryState.CALCULATING; // Updating status using enum before requesting the requestId
    uint256 requestId = i_vrfCoordinator.requestRandomWords(
      i_gasLane, // aka keyHash; aka max gas price you are willing to pay for a request in wei; aka setting a gas ceiling
      i_subscriptionId, // aka a uint64 subscription ID that this contract uses for funding requests
      REQUEST_CONFIRMATIONS, // A uint16 which says how many confirmations the chainlink node should wait before responding
      i_callbackGasLimit, // A uint32 which sets gas limit for callback request aka `fulfillRandomWords()`
      NUM_WORDS // a uint32 about how many random number we want to get
    ); // requestRandomWords: https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol
    emit RequestedLotteryWinner(requestId); // This emit is redundant as its already coded in vrfcoordinatorv2mock
  }

  // Once requested, do something with it (2/2); Here: Pick a random winner from the player's array and send him the money
  /**
   * @notice Handles the fulfillment of a random number request and selects the winner.
   * @dev This function is called internally when the VRF response is received.
   * @param randomWords An array of random words generated by Chainlink VRF.
   * @dev The function selects a winner by taking the modulus of the first random word with the number of players.
   * @dev Transfers the lottery funds to the winner and emits the `WinnerPicked` event.
   * @dev Resets the player array and the timestamp for the next round of the lottery.
   * @dev Once winner is picked, changes the lottery state to Open.
   */
  function fulfillRandomWords(
    uint256 /* requestId */,
    uint256[] memory randomWords
  ) internal override {
    uint256 indexOfWinner = randomWords[0] % s_players.length; // Index 0 as we are only getting 1 random word from the array of words; % use example: 202 (random number) % 10 (entries) = 2 remainder (winner)
    address payable recentWinner = s_players[indexOfWinner];
    s_recentWinner = recentWinner;
    s_lotteryState = LotteryState.OPEN; // Changing status to open after winner selection

    // Sending money to winner
    (bool success, ) = recentWinner.call{ value: address(this).balance }(""); // call function syntax: (bool success, bytes memory data) = targetAddress.call{value: amount}(functionSignature);
    // Other method: require(success); Using the below one to be gas-efficient and record errors
    if (!success) {
      revert Lottery__WinnerTransferFailed();
    }
    // Keeping a list of all winners (outside of the contract, in the logs. As there is no array of winners written yet)
    emit WinnerPicked(recentWinner);

    // Resetting array & timestamp
    s_players = new address payable[](0); // Array of size 0
    s_lastTimeStamp = block.timestamp;
  } // Reference: https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol

  // View & Pure Functions
  function getEntranceFee() public view returns (uint256) {
    return i_entranceFee;
  }

  function getPlayers(uint256 index) public view returns (address) {
    return s_players[index];
  }

  function getRecentWinner() public view returns (address) {
    return s_recentWinner;
  }

  function getLotteryState() public view returns (LotteryState) {
    return s_lotteryState;
  }

  function getNumWords() public pure returns (uint256) {
    return NUM_WORDS;
  }

  function getNumberOfPlayers() public view returns (uint256) {
    return s_players.length;
  }

  function getLatestTimeStamp() public view returns (uint256) {
    return s_lastTimeStamp;
  }

  function getRequestConfirmations() public pure returns (uint256) {
    return REQUEST_CONFIRMATIONS;
  }

  function getInterval() public view returns (uint256) {
    return i_interval;
  }
}
