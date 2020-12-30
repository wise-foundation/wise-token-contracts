// SPDX-License-Identifier: --🦉--

pragma solidity =0.7.6;

import "./Helper.sol";

abstract contract Snapshot is Helper {

    using SafeMath for uint;

    // regular shares
    struct SnapShot {
        uint256 totalShares;
        uint256 inflationAmount;
        uint256 scheduledToEnd;
    }

    // referral shares
    struct rSnapShot {
        uint256 totalShares;
        uint256 inflationAmount;
        uint256 scheduledToEnd;
    }

    // liquidity shares
    struct lSnapShot {
        uint256 totalShares;
        uint256 inflationAmount;
    }

    mapping(uint256 => SnapShot) public snapshots;
    mapping(uint256 => rSnapShot) public rsnapshots;
    mapping(uint256 => lSnapShot) public lsnapshots;

    modifier snapshotTrigger() {
        _dailySnapshotPoint(_currentWiseDay());
        _;
    }

    /**
     * @notice allows to activate/deactivate
     * liquidity guard manually based on the
     * liquidity in UNISWAP pair contract
     */
    function liquidityGuardTrigger() public {

        (
            uint112 reserveA,
            uint112 reserveB,
            uint32 blockTimestampLast
        ) = UNISWAP_PAIR.getReserves();

        emit UniswapReserves(
            reserveA,
            reserveB,
            blockTimestampLast
        );

        uint256 onUniswap = UNISWAP_PAIR.token1() == WETH
            ? reserveA
            : reserveB;

        uint256 ratio = totalSupply() == 0
            ? 0
            : onUniswap
                .mul(200)
                .div(totalSupply());

        if (ratio < 40 && isLiquidityGuardActive == false) enableLiquidityGuard();
        if (ratio > 60 && isLiquidityGuardActive == true) disableLiquidityGuard();

        emit LiquidityGuardStatus(
            isLiquidityGuardActive
        );
    }

    function enableLiquidityGuard() private {
        isLiquidityGuardActive = true;
    }

    function disableLiquidityGuard() private {
        isLiquidityGuardActive = false;
    }

    /**
     * @notice allows volunteer to offload snapshots
     * to save on gas during next start/end stake
     */
    function manualDailySnapshot()
        external
    {
        _dailySnapshotPoint(_currentWiseDay());
    }

    /**
     * @notice allows volunteer to offload snapshots
     * to save on gas during next start/end stake
     * in case manualDailySnapshot reach block limit
     */
    function manualDailySnapshotPoint(
        uint64 _updateDay
    )
        external
    {
        require(
            _updateDay > 0 &&
            _updateDay < _currentWiseDay()
            // 'WISE: snapshot day does not exist yet'
        );

        require(
            _updateDay > globals.currentWiseDay
            // 'WISE: snapshot already taken for that day'
        );

        _dailySnapshotPoint(_updateDay);
    }

    /**
     * @notice internal function that offloads
     * global values to daily snapshots
     * updates globals.currentWiseDay
     */
    function _dailySnapshotPoint(
        uint64 _updateDay
    )
        private
    {
        liquidityGuardTrigger();

        uint256 scheduledToEndToday;
        uint256 totalStakedToday = globals.totalStaked;

        for (uint256 _day = globals.currentWiseDay; _day < _updateDay; _day++) {

            // ------------------------------------
            // prepare snapshot for regular shares
            // reusing scheduledToEndToday variable

            scheduledToEndToday = scheduledToEnd[_day] + snapshots[_day - 1].scheduledToEnd;

            SnapShot memory snapshot = snapshots[_day];
            snapshot.scheduledToEnd = scheduledToEndToday;

            snapshot.totalShares =
                globals.totalShares > scheduledToEndToday ?
                globals.totalShares - scheduledToEndToday : 0;

            snapshot.inflationAmount =  snapshot.totalShares
                .mul(PRECISION_RATE)
                .div(
                    _inflationAmount(
                        totalStakedToday,
                        totalSupply(),
                        totalPenalties[_day],
                        LIQUIDITY_GUARD.getInflation(
                            INFLATION_RATE
                        )
                    )
                );

            // store regular snapshot
            snapshots[_day] = snapshot;


            // ------------------------------------
            // prepare snapshot for referrer shares
            // reusing scheduledToEndToday variable

            scheduledToEndToday = referralSharesToEnd[_day] + rsnapshots[_day - 1].scheduledToEnd;

            rSnapShot memory rsnapshot = rsnapshots[_day];
            rsnapshot.scheduledToEnd = scheduledToEndToday;

            rsnapshot.totalShares =
                globals.referralShares > scheduledToEndToday ?
                globals.referralShares - scheduledToEndToday : 0;

            rsnapshot.inflationAmount = rsnapshot.totalShares
                .mul(PRECISION_RATE)
                .div(
                    _referralInflation(
                        totalStakedToday,
                        totalSupply()
                    )
                );

            // store referral snapshot
            rsnapshots[_day] = rsnapshot;


            // ------------------------------------
            // prepare snapshot for liquidity shares
            // reusing scheduledToEndToday variable

            lSnapShot memory lsnapshot = lsnapshots[_day];
            lsnapshot.totalShares = globals.liquidityShares;

            lsnapshot.inflationAmount = lsnapshot.totalShares
                .mul(PRECISION_RATE).div(
                    _liquidityInflation(
                        totalStakedToday,
                        totalSupply(),
                        LIQUIDITY_GUARD.getInflation(
                            LIQUIDITY_RATE
                        )
                    )
                );

            // store liquidity snapshot
            lsnapshots[_day] = lsnapshot;

            adjustLiquidityRates();
            globals.currentWiseDay++;
        }
    }

    /**
     * @notice moves inflation up and down by 0.006%
     * from regular shares to liquidity shares
     * if the liquidityGuard is active (visa-versa)
     */
    function adjustLiquidityRates() private {
        if (
            isLiquidityGuardActive ==  true &&
            LIQUIDITY_RATE < INFLATION_RATE_MAX
            )
        {
            LIQUIDITY_RATE = LIQUIDITY_RATE + 6;
            INFLATION_RATE = INFLATION_RATE - 6;
            return;
        }
        if (
            isLiquidityGuardActive == false &&
            INFLATION_RATE < INFLATION_RATE_MAX
            )
        {
            INFLATION_RATE = INFLATION_RATE + 6;
            LIQUIDITY_RATE = LIQUIDITY_RATE - 6;
            return;
        }
    }

    function _inflationAmount(uint256 _totalStaked, uint256 _totalSupply, uint256 _totalPenalties, uint256 _INFLATION_RATE) private pure returns (uint256) {
        return (_totalStaked + _totalSupply) * 10000 / _INFLATION_RATE + _totalPenalties;
    }

    function _referralInflation(uint256 _totalStaked, uint256 _totalSupply) private pure returns (uint256) {
        return (_totalStaked + _totalSupply) * 10000 / REFERRALS_RATE;
    }

    function _liquidityInflation(uint256 _totalStaked, uint256 _totalSupply, uint256 _LIQUIDITY_RATE) private pure returns (uint256) {
        return (_totalStaked + _totalSupply) * 10000 / _LIQUIDITY_RATE;
    }
}