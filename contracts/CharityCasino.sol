//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

/*  

     TO DISCUSS:


        Spin the wheel =>
        Receive/Calculate Outcome --- possibly from another contract?
        send NFT to player --- possibly from another contract?

        How to calculate player reward?

        How to calculate bet limit?

        Integration with front end:
            Can the front end successfully approve through "approvePlayerAllowancePerSpin"
            and call donate to make the transfer OR 
            should the front end just call the ERC20 approve and transferFrom function??

    
    TODO:

    If player wins: 'calculatePlayerReward'

    'calculateBetLimit' based on the amount of tokens we have to repay winning players.


*/

contract CharityCasino is Ownable, VRFConsumerBase {
    mapping(address => uint256) public playerTotalAmountSpent;
    mapping(address => uint256) public playerAllowanceUsd;
    mapping(address => uint256) public playerAllowanceMtc;
    mapping(address => address) public tokenPriceFeedMapping;
    uint256 usd_allowance;
    uint256 token_allowance;
    uint256 bet_amount;
    uint256 public SPINNING_THRESHOLD = 50; // Usd
    uint256 public fee;
    uint256 public randomness;
    bytes32 public keyhash;
    bool public wheel_approval = false;
    bool public playerWins = false;
    address[] public allowedTokens;
    address public prizePool;
    address public link;
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
        tokenPriceFeedMapping[_maticAddress] = _maticPriceFeed;
        prizePool = payable(address(this));
        link = _link;
    }

    function calculateBetLimit(address _token) public view returns (uint256) {
        // calcualte bet limit based on the amount of tokens we have to repay winning players.
        // -> DISPLAY bet limit ON FRONTEND
        // calculate betlimit in tokens
        //calculate bet limit in dollars
        // update bet limit variable
        return 100;
    }

    function approvePlayerAllowancePerSpin(address _token, uint256 _amount)
        public
    {
        // Check to see if the token being updated is allowed
        require(
            tokenIsAllowed(_token),
            "This token is not supported, please use MATIC to place your bets!"
        );

        // get token value in dollars:
        (uint256 price, uint256 decimals) = getTokenValue(_token);

        playerAllowanceUsd[msg.sender] = (_amount * price) / (10**decimals); // DISPLAY playerAllowanceUsd ON FRONTEND
        usd_allowance = playerAllowanceUsd[msg.sender];

        //Update matic allowance mappping
        playerAllowanceMtc[msg.sender] = _amount;
        token_allowance = _amount;

        // call approve function and set it equal to token_allowance;
        IERC20(_token).approve(address(this), _amount);
    }

    // call on front end when slot machine starts
    function makeBet(address _token, uint256 _amount) public payable {
        uint256 max_allowance = playerAllowanceUsd[msg.sender];
        uint256 bet_limit = calculateBetLimit(_token);
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
    }

    // if player lost:
    // takes input in MATIC
    function donate(
        address _token,
        address _playerAddress,
        address _charityAddress,
        uint256 _amount
    ) public {
        // send player bet amount to charity -- maybe keep a portion to increase prize pool???
        // if testnet pay my account, if mainnet/polygon pay actual charity
        require(
            tokenIsAllowed(_token),
            "This token is not supported, please donate using MATIC"
        );

        IERC20(_token).transferFrom(_playerAddress, _charityAddress, _amount);
    }

    // if player won:
    function payPlayer(
        address _token,
        address _playerAddress,
        uint256 _amount
    ) public onlyOwner {
        uint256 player_reward = calculatePlayerReward(_amount);
        // IERC20(_token).transfer(_playerAddress, player_reward);
    }

    function calculatePlayerReward(uint256 _amount)
        public
        onlyOwner
        returns (uint256 reward)
    {}

    function spinTheWheel() public {
        require(wheel_approval == true);
        bytes32 requestId = requestRandomness(keyhash, fee);
        emit RequestRandomness(requestId);

        // Receive/Calculate Outcome --- possibly from another contract
        // send NFT to player --- possibly from another contract

        // reset approval to false
        wheel_approval == false;
    }

    // Add button to front end for donations to the prize pool. Pass {msg.value} = to donation amount
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

    receive() external payable {}
}
