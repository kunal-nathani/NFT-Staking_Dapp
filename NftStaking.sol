// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ERC721Staking is ReentrancyGuard{
    using SafeERC20 for IERC20;

    //Interfaces for ERC20 and ERC721
    IERC20 public immutable rewardsToken;
    IERC721 public immutable nftCollection;

    // Constructor function to set the rewards token and the NFT collection addresses
    constructor(IERC721 _nftCollection, IERC20 _rewardsToken){
        nftCollection = _nftCollection;
        rewardsToken = _rewardsToken;
    }

    struct StakedToken{
        address staker;
        uint256 tokenId;
    }

    //Staker info
    struct Staker{
        //Amount of tokens staked by the staker
        uint256 amountStaked;

        //Staked tokens
        StakedToken[] stakedTokens;

        // Last time of the rewards were calculated for this user
        uint256 timeofLastUpdate;

        //Calculated , but unclaimed rewards for the user .The rewards are
        //calculated each time as the user writes to the Smarrt Contract
        uint256 unclaimedRewards;
    }

    //Rewards per hour per token deposited on wei.
    //Rewards  are calculated once every hour.
    uint256 private rewardsPerHour = 100000;

    //Mappping of User Address to Staker info
    mapping(address => Staker) public stakers;

    //Mapping of Token Id to staker. Made for the SC to remember
    //who to send back the ERC721 Token to.
    mapping(uint256 => address) public stakerAddress;

    function stake(uint256 _tokenId) external nonReentrant{
        //If wallet has token staked, calculate the rewards before adding the new token
        if(stakers[msg.sender].amountStaked > 0){
            uint256 rewards = calculateRewards(msg.sender);
            stakers[msg.sender].unclaimedRewards += rewards;
        }

        //Wallet must own the token they are trying to stake
        require(
            nftCollection.ownerOf(_tokenId) == msg.sender,
            "You don't own thos token!"
        );

        //Transfer the token from the wallet to the smart contract
        nftCollection.transferFrom(msg.sender, address(this), _tokenId);

        // Create StakedToken
        StakedToken memory stakedToken = StakedToken(msg.sender, _tokenId);

        // Add the token to the stakedTokens array
        stakers[msg.sender].stakedTokens.push(stakedToken);

        //Increment the amount staked for this wallet
        stakers[msg.sender].amountStaked++;

        //update the mapping of the tokenid to the staker's address
        stakerAddress[_tokenId] = msg.sender;

        // update the timeOfLastUpdate for the staker
        stakers[msg.sender].timeofLastUpdate = block.timestamp;
    }

    function withdraw(uint256 _tokenId) external nonReentrant{
        // Make sure the user has at least one token staked before withdrawing
        require(
            stakers[msg.sender].amountStaked > 0,
            "You have no tokens staked"
        ); 

        // Wallet must own the token they are trying to withdraw
        require(stakerAddress[_tokenId] == msg.sender, "You don't own this token!");


        // Update the rewards for this user, as the amount of rewards decreases with less tokens.
        uint256 rewards = calculateRewards (msg.sender);
        stakers[msg.sender].unclaimedRewards += rewards;

        // Find the index of this token id in the stakedTokens array
        uint256 index = 0;
        for (uint256 i = 0; i < stakers[msg.sender].stakedTokens.length; i++) {
        if (stakers[msg.sender].stakedTokens[i].tokenId == _tokenId) {
                index = i;
                break;
            }
        }

        // Remove this token from the staked Tokens array
        stakers[msg.sender].stakedTokens[index].staker = address (0);
        
        // Decrement the amount staked for this wallet
        stakers[msg.sender].amountStaked--;

        // Update the mapping of the tokenId to the be address (0) to indicate that the token is no longer staked
        stakerAddress [_tokenId] = address(0);

        // Transfer the token back to the withdrawer
        nftCollection.transferFrom(address(this), msg.sender, _tokenId);

        // Update the timeOfLast Update for the withdrawer
        stakers[msg.sender].timeofLastUpdate = block.timestamp;
    }

    function claimRewards() external {
            uint256 rewards = calculateRewards (msg.sender) +
                stakers [msg.sender].unclaimedRewards;

            require(rewards > 0, "You have no rewards to claim");

            stakers [msg.sender].timeofLastUpdate = block.timestamp;
            stakers [msg.sender].unclaimedRewards = 0;

            rewardsToken.safeTransfer (msg.sender, rewards);
            }

            function calculateRewards (address _staker)
            internal
            view
            returns (uint256 _rewards)
            {
            return (((
                    ((block.timestamp - stakers[_staker].timeofLastUpdate) *
                        stakers [_staker]. amountStaked)
                    ) * rewardsPerHour) / 3600);
         
            }

        function availableRewards (address _staker) public view returns (uint256) {
            uint256 rewards = calculateRewards(_staker) +
                stakers[_staker].unclaimedRewards;
            return rewards;
        }

        function getStakedTokens(address _user) public view returns (StakedToken[] memory) {
            // Check if we know this user
            if (stakers[_user].amountStaked > 0) {
                // Return all the tokens in the staked Token Array for this user that are not -1
                StakedToken[] memory _stakedTokens = new StakedToken[] (stakers[_user].amountStaked);
                uint256 _index = 0;

            for (uint256 j = 0; j < stakers[_user].stakedTokens.length; j++) {
                if (stakers[_user].stakedTokens [j].staker != (address (0))) {
                    _stakedTokens[_index] = stakers [_user].stakedTokens[j];
                    _index++;
                }
            }
            
            return _stakedTokens;
        }

        // Otherwise, return empty array
        else {
                return new StakedToken [](0);
            }
        }
}