// SPDX-License-Identifier: --🦉--

pragma solidity =0.7.6;

contract Events {

    event StakeStart(
        bytes16 indexed stakeID,
        address indexed stakerAddress,
        address indexed referralAddress,
        uint256 stakedAmount,
        uint256 stakesShares,
        uint256 referralShares,
        uint256 startDay,
        uint256 lockDays,
        uint256 daiEquivalent
    );

    event StakeEnd(
        bytes16 indexed stakeID,
        address indexed stakerAddress,
        address indexed referralAddress,
        uint256 stakedAmount,
        uint256 stakesShares,
        uint256 referralShares,
        uint256 rewardAmount,
        uint256 closeDay,
        uint256 penaltyAmount
    );

    event InterestScraped(
        bytes16 indexed stakeID,
        address indexed stakerAddress,
        uint256 scrapeAmount,
        uint256 scrapeDay,
        uint256 stakersPenalty,
        uint256 referrerPenalty,
        uint256 currentWiseDay
    );

    event ReferralCollected(
        address indexed staker,
        bytes16 indexed stakeID,
        address indexed referrer,
        bytes16 referrerID,
        uint256 rewardAmount
    );

    event NewGlobals(
        uint256 totalShares,
        uint256 totalStaked,
        uint256 shareRate,
        uint256 referrerShares,
        uint256 indexed currentWiseDay
    );

    event NewSharePrice(
        uint256 newSharePrice,
        uint256 oldSharePrice,
        uint64 currentWiseDay
    );

    event UniswapReserves(
        uint112 reserveA,
        uint112 reserveB,
        uint32 blockTimestampLast
    );

    event LiquidityGuardStatus(
        bool isActive
    );
}