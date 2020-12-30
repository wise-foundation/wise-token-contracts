// SPDX-License-Identifier: --🦉--

pragma solidity =0.7.6;

import "./StakingToken.sol";

abstract contract LiquidityToken is StakingToken {

    using SafeMath for uint;

    /**
     * @notice A method for a staker to create a liquidity stake
     * @param _liquidityTokens amount of UNI-WISE staked.
     */
    function createLiquidityStake(
        uint256 _liquidityTokens
    )
        snapshotTrigger
        external
        returns (bytes16 liquidityStakeID)
    {
        require(
            isLiquidityGuardActive == true
            // WISE: LiquidityGuard is not active
        );

        safeTransferFrom(
            address(UNISWAP_PAIR),
            msg.sender,
            address(this),
            _liquidityTokens
        );

        LiquidityStake memory newLiquidityStake;

        liquidityStakeID = generateLiquidityStakeID(
            msg.sender
        );

        newLiquidityStake.startDay = _nextWiseDay();
        newLiquidityStake.stakedAmount = _liquidityTokens;
        newLiquidityStake.isActive = true;

        globals.liquidityShares =
        globals.liquidityShares.add(_liquidityTokens);

        liquidityStakes[msg.sender][liquidityStakeID] = newLiquidityStake;

        _increaseLiquidityStakeCount(
            msg.sender
        );
    }

    /**
     * @notice A method for a staker to end a liquidity stake
     * @param _liquidityStakeID - identification number
     */
    function endLiquidityStake(
        bytes16 _liquidityStakeID
    )
        snapshotTrigger
        external
        returns (uint256)
    {
        LiquidityStake memory liquidityStake =
        liquidityStakes[msg.sender][_liquidityStakeID];

        require(
            liquidityStake.isActive
            // 'WISE: not an active stake'
        );

        liquidityStake.isActive = false;
        liquidityStake.closeDay = _currentWiseDay();

        liquidityStake.rewardAmount = _calculateRewardAmount(
            liquidityStake
        );

        _mint(
            msg.sender,
            liquidityStake.rewardAmount
        );

        safeTransfer(
            address(UNISWAP_PAIR),
            msg.sender,
            liquidityStake.stakedAmount
        );

        globals.liquidityShares =
        globals.liquidityShares.sub(liquidityStake.stakedAmount);

        liquidityStakes[msg.sender][_liquidityStakeID] = liquidityStake;

        return liquidityStake.rewardAmount;
    }

    /**
     * @notice returns full view and details of
     * a liquidity stake belonging to caller
     * @param _liquidityStakeID - stakeID
     */
    function checkLiquidityStakeByID(
        address _staker,
        bytes16 _liquidityStakeID
    )
        external
        view
        returns (
            uint256 startDay,
            uint256 stakedAmount,
            uint256 rewardAmount,
            uint256 closeDay,
            bool isActive
        )
    {
        LiquidityStake memory stake = liquidityStakes[_staker][_liquidityStakeID];
        startDay = stake.startDay;
        stakedAmount = stake.stakedAmount;
        rewardAmount = _calculateRewardAmount(stake);
        closeDay = stake.closeDay;
        isActive = stake.isActive;
    }

    /**
     * @notice calculates reward when closing liquidity stake
     * @param _liquidityStake - stake instance
     */
    function _calculateRewardAmount(
        LiquidityStake memory _liquidityStake
    )
        private
        view
        returns (uint256 _rewardAmount)
    {
        uint256 maxCalculationDay = _liquidityStake.startDay + MIN_REFERRAL_DAYS;

        uint256 calculationDay =
            globals.currentWiseDay < maxCalculationDay ?
            globals.currentWiseDay : maxCalculationDay;

        for (uint256 _day = _liquidityStake.startDay; _day < calculationDay; _day++) {
            _rewardAmount += _liquidityStake.stakedAmount * PRECISION_RATE / lsnapshots[_day].inflationAmount;
        }
    }
}