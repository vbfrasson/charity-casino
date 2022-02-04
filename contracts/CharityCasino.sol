//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// fund contract with link
// Allowed token functions

contract CharityCasino is Ownable, VRFConsumerBase {
    // mapping(address => uint256) playerBetAmount;  is this necessary at all?
    mapping(address => uint256) playerTotalAmountSpent;
    mapping(address => uint256) playerAllowanceUsd;
    mapping(address => address) tokenPriceFeedMapping;
    uint256 bet_limit;
    uint256 bet_amount;
    uint256 SPINNING_THRESHOLD = 50; // Usd
    uint256 public fee;
    uint256 public randomness;
    bytes32 public keyhash;
    bool wheel_approval = false;
    bool playerWins = false;
    address[] public allowedTokens;
    event RequestRandomness(bytes32 requestId);

    constructor(
        address _maticAddress,
        address _maticPriceFeed,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyhash
    ) public VRFConsumerBase(_vrfCoordinator, _link) {
        fee = _fee;
        keyhash = _keyhash;
        allowedTokens.push(_maticAddress);
        tokenPriceFeedMapping[_maticAddress];
    }

    function calculateBetLimit(address _token) public view returns (uint256) {
        // calcualte bet limit based on the amount of tokens we have to repay winning players.
        // -> DISPLAY bet limit ON FRONTEND
        // calculate betlimit in tokens
        //calculate bet limit in dollars
        // update bet limit variable
    }

    function updatePlayerAllowance(uint256 _amount, address _token)
        public
        returns (uint256 max_usd_amount, uint256 max_token_amount)
    {
        // Check to see if the token being updated is allowed
        require(
            tokenIsAllowed(_token),
            "This token is not supported, please use MATIC to place your bets!"
        );

        playerAllowanceUsd[msg.sender] = _amount; // DISPLAY playerAllowanceUsd ON FRONTEND
        uint256 token_allowance = setAllowanceTokenAmount(_token);
        return (_amount, token_allowance);
    }

    // DISPLAY MAX TOKEN AMOUNT NEXT TO MAX DOLAR AMOUNT front end
    function setAllowanceTokenAmount(address _token)
        public
        returns (uint256 token_allowance)
    {
        // get token value in dollars:
        (uint256 price, uint256 decimals) = getTokenValue(_token);

        // set max token quantity based on dollar amount (playerAllowanceUsd[msg.sender])
        uint256 max_token_amount = playerAllowanceUsd[msg.sender] /
            (price / (10**decimals));

        // call approve function and set it equal to max token amount;
        IERC20(_token).approve(address(this), max_token_amount);
        return max_token_amount;
    }

    function makeBet(address _token, uint256 _amount) public payable {
        uint256 max_allowance = playerAllowanceUsd[msg.sender];

        require(_amount > 0, "Your bet must be higher than 0");
        require(
            _amount < bet_limit,
            "Your bet reward could exceed the total prize, please bet according to the betting limit" //
        );
        require(
            _amount <= max_allowance,
            "You cannot bet higher than your bet allowance amount!"
        );
        bytes32 requestId = requestRandomness(keyhash, fee);
        emit RequestRandomness(requestId);

        playerTotalAmountSpent[msg.sender] =
            playerTotalAmountSpent[msg.sender] +
            _amount;
        if (playerTotalAmountSpent[msg.sender] == SPINNING_THRESHOLD) {
            wheel_approval = false;
        }

        // (uint256 price, uint256 decimals) = getTokenValue(_token);

        // // convert amount to token value
        // uint256 token_amount = price;
    }

    // function PayWinner(address _charityAddress, uint256 _amount)
    //     public
    //     onlyOwner
    //     returns (address winner, uint256 reward)
    // {
    //     //Insert random number here??

    //     // do something to calcualte win or lose
    //     //change state of playerWins if necessary

    //     // if player lost: donate()
    //     if (playerWins == false) {
    //         payPlayer(_amount);
    //     }

    //     // if player won: pay player()

    //     // update bet limit
    // }

    // if player lost:
    function donate(
        uint256 _amount,
        address _token,
        address _charityAddress
    ) private {
        // send player bet amount to charity -- maybe keep a portion to increase prize pool???
        // if testnet pay my account, if mainnet/polygon pay actual charity

        IERC20(_token).transferFrom(msg.sender, _charityAddress, _amount);
    }

    // if player won:
    function payPlayer(uint256 _amount) private {
        calculatePlayerReward(_amount);
    }

    function calculatePlayerReward(uint256 _amount)
        private
        view
        returns (uint256 reward)
    {}

    function spinTheWheel() public {
        require(wheel_approval == true);
        bytes32 requestId = requestRandomness(keyhash, fee);
        emit RequestRandomness(requestId);

        // Receive/Calculate Outcome
        // send NFT to player --- possibly another function

        // reset approval to false
        wheel_approval == false;
    }

    function IncreasePrizePool() public payable {
        //increases prize pool of given token. Serves as a donation portal for the casino itself.
    }

    function setPriceFeedContract(address _token, address _priceFeed)
        public
        onlyOwner
    {
        // set price feed address to whens adding new tokens or changing existing ones.
        tokenPriceFeedMapping[_token] = _priceFeed;
    }

    function getTokenValue(address _token)
        public
        view
        returns (uint256, uint256)
    {
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = uint256(priceFeed.decimals());
        return (uint256(price), decimals);
    }

    function tokenIsAllowed(address _token) public returns (bool) {
        // how to loop trough mappings/arrays efficiently without excessive gas cost??
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
        }
        return false;
    }

    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        require(_randomness > 0, "random number not found.");
        randomness = _randomness;
    }
}

// player approves max bet amount only once with and that value is never changed after.
//  only if player calls it. - DONE
// player then bets based on that maximum amount. - DONE

// Enable players to choose what cryptocurrency they want to use. ADD tokens
// When players click deposit bet they also  - DONE
// approve for us to transfer it to charity in case of loss. - DONE
// get random number from polygon/chainlink -DONE

// If player wins: calcualte how much he wins.

// get priceFeed so users can see bet in dollars. -DONE

// function where player chooses how to donate. *
// Accept different ERC20s *

//fund slot machine with test net money.
