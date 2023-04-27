// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Objective:
// 1. Enter the lottery (paying some amount)
// 2. Pick a random winner (verifiably random) (Winner to be selected once a parameter is satisfied. Eg: time, asset price, money in liquidity pool etc)
// 3. Completely automated:
//  * The following should be true in order to return true:
//  * i. Our time internal should have passed
//  * ii. The lottery should have atleast 1 player, and have some ETH
//  * iii. Our subscription is funded with LINK
//  * iv. The lottery should be in an "open" state.

// As we are picking random winner (2) and we have some event driven execution (3), we will use Chainlink Oracles
// Aka Chainlink Oracles for Randomness and Automated Execution (ie Chainlink Keepers)

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Lottery__NotEnoughETHEntered();
error Lottery__WinnerTransferFailed();
error Lottery__NotOpen();
error Lottery_checkUpKeepfalse(
    uint256 currentBalance,
    uint256 numPlayers,
    uint256 lotteryState
);

/**
 * @title A sample lottery contract
 * @author Jatin Kalra
 * @notice A contract for creating an untamperable decentralised smart contract
 * @dev This implements Chainlink VRF V2 & Chainlink Keepers
 */

contract Lottery is
    VRFConsumerBaseV2 /* Inheritance for overriding the internal function from "./node_modules" */,
    KeeperCompatibleInterface
{
    // Type Declaration
    enum LotteryState {
        OPEN,
        CALCULATING
    } // in background: uint256 0 = OPEN, 1 = CALCULATING

    // State Variables
    uint256 private immutable i_entranceFee; // minimum price // A storage var
    address payable[] private s_players; // payable addresses as if one of them wins, we would be paying them
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
    uint256 private i_interval; // interval between each winner

    // Events
    event LotteryEnter(address indexed player);
    event RequestedLotteryWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    // Functions
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
    function enterLottery() public payable {
        // Other method: require (msg.value > i_entranceFee, "Not Enough ETH!")
        if (msg.value < i_entranceFee) {
            revert Lottery__NotEnoughETHEntered();
        }
        if (s_lotteryState != LotteryState.OPEN) {
            revert Lottery__NotOpen();
        }
        s_players.push(payable(msg.sender));

        // Emit an Event whenever we update a dynamic array or mapping
        emit LotteryEnter(msg.sender);
    }

    // Objective (3/3: Completely automated)

    /**
     * @dev This is a function that Chainlink Keepers nodes call
     * They look for the `upkeepNeeded` to return true
     * The following should be true in order to return true:
     * i. Our time internal should have passed
     * ii. The lottery should have atleast 1 player, and have some ETH
     * iii. Our subscription is funded with LINK
     * iv. The lottery should be in an "open" state.
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/)
    {
        //  iv. The lottery should be in an "open" state.
        bool isOpen = (LotteryState.OPEN == s_lotteryState);

        // i. Our time internal should have passed (ie: (current block.timestamp - last block.timestamp) > winner interval)
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);

        //  ii. The lottery should have atleast 1 player, and have some ETH
        bool hasPlayers = (s_players.length > 0);

        //  iii. Our subscription is funded with LINK
        bool hasBalance = (address(this).balance > 0);

        // Checking if all booleans are true or not, in order to restart lottery
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    // Objective (2/3: Pick a random winner)
    // To pick a random number, a 2 transaction process: Request a random number (1/2); Once requested, do something with it (2/2)
    // Request a random number (1/2)
    // function requestRandomWinner() external {
    function performUpkeep(bytes calldata /*performData*/) external {
        (bool upkeepNeeded, ) = checkUpkeep(""); // checking if heckUpKeep is true
        if (!upkeepNeeded) {
            revert Lottery_checkUpKeepfalse(
                address(this).balance,
                s_players.length,
                uint256(s_lotteryState)
            );
        }

        s_lotteryState = LotteryState.CALCULATING; // Updating status using enum
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // aka keyHash; aka max gas price you are willing to pay for a request in wei; aka setting a gas ceiling
            i_subscriptionId, // aka a uint64 subscription ID that this contract uses for funding requests
            REQUEST_CONFIRMATIONS, // A uint16 which says how many confirmations the chainlink node should wait before responding
            i_callbackGasLimit, // A uint32 which sets gas limit for callback request aka `fulfillRandomWords()`
            NUM_WORDS // a uint32 about how many random number we want to get
        );
        emit RequestedLotteryWinner(requestId);  // This emit is redundant as its already coded in vrfcoordinatorv2mock

    }

    // Once requested, do something with it (2/2); Here: Pick a random winner from the player's array and send him the money
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_lotteryState = LotteryState.OPEN; // Changing status to open after winner selection

        // Sending money to winner
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery__WinnerTransferFailed();
        } // error report
        // Keeping a list of all winners
        emit WinnerPicked(recentWinner);

        // Resetting array & timestamp
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
    }

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
