// SPDX-License-Identifier: --🦉--

pragma solidity =0.7.4;

import "./Snapshot.sol";

abstract contract ReferralToken is Snapshot {

    using SafeMath for uint256;

    function _addReferrerSharesToEnd(
        uint256 _finalDay,
        uint256 _shares
    )
        internal
    {
        referralSharesToEnd[_finalDay] =
        referralSharesToEnd[_finalDay].add(_shares);
    }

    function _removeReferrerSharesToEnd(
        uint256 _finalDay,
        uint256 _shares
    )
        internal
    {
        if (_notPast(_finalDay)) {

            referralSharesToEnd[_finalDay] =
            referralSharesToEnd[_finalDay] > _shares ?
            referralSharesToEnd[_finalDay] - _shares : 0;

        } else {

            uint256 _day = _previousWiseDay();
            rsnapshots[_day].scheduledToEnd =
            rsnapshots[_day].scheduledToEnd > _shares ?
            rsnapshots[_day].scheduledToEnd - _shares : 0;
        }
    }

    function _belowThresholdLevel(
        address _referrer
    )
        private
        view
        returns (bool)
    {
        return criticalMass[_referrer].totalAmount < THRESHOLD_LIMIT;
    }

    function _addCriticalMass(
        address _referrer,
        uint256 _daiEquivalent
    )
        internal
    {
        criticalMass[_referrer].totalAmount =
        criticalMass[_referrer].totalAmount.add(_daiEquivalent);
        criticalMass[_referrer].activationDay = _determineActivationDay(_referrer);
    }

    function _removeCriticalMass(
        address _referrer,
        uint256 _daiEquivalent,
        uint256 _startDay
    )
        internal
    {
        if (
            _notFuture(_startDay) == false &&
            _nonZeroAddress(_referrer)
        ) {
            criticalMass[_referrer].totalAmount =
            criticalMass[_referrer].totalAmount > _daiEquivalent ?
            criticalMass[_referrer].totalAmount - _daiEquivalent : 0;
            criticalMass[_referrer].activationDay = _determineActivationDay(_referrer);
        }
    }

    function _determineActivationDay(
        address _referrer
    )
        private
        view
        returns (uint256)
    {
        return _belowThresholdLevel(_referrer) ? 0 : _activationDay(_referrer);
    }

    function _activationDay(
        address _referrer
    )
        private
        view
        returns (uint256)
    {
        return
            criticalMass[_referrer].activationDay > 0 ?
            criticalMass[_referrer].activationDay : _currentWiseDay();
    }

    function _updateDaiEquivalent()
        internal
        returns (uint256)
    {
        try UNISWAP_ROUTER.getAmountsOut(
            YODAS_PER_WISE, _path
        ) returns (uint256[] memory results) {
            latestDaiEquivalent = results[2];
            return latestDaiEquivalent;
        } catch Error(string memory) {
            return latestDaiEquivalent;
        } catch (bytes memory) {
            return latestDaiEquivalent;
        }
    }

    function referrerInterest(
        bytes16 _referralID,
        uint256 _scrapeDays
    )
        external
        snapshotTrigger
    {
        _referrerInterest(
            msg.sender,
            _referralID,
            _scrapeDays
        );
    }

    function referrerInterestBulk(
        bytes16[] memory _referralIDs,
        uint256[] memory _scrapeDays
    )
        external
        snapshotTrigger
    {
        for(uint256 i = 0; i < _referralIDs.length; i++) {
            _referrerInterest(
                msg.sender,
                _referralIDs[i],
                _scrapeDays[i]
            );
        }
    }

    function _referrerInterest(
        address _referrer,
        bytes16 _referralID,
        uint256 _processDays
    )
        internal
    {
        ReferrerLink memory link =
        referrerLinks[_referrer][_referralID];

        require(
            link.isActive == true
        );

        address staker = link.staker;
        bytes16 stakeID = link.stakeID;

        Stake memory stake = stakes[staker][stakeID];

        uint256 startDay = _determineStartDay(stake, link);
        uint256 finalDay = _determineFinalDay(stake);

        if (_stakeEnded(stake)) {

            if (
                _processDays > 0 &&
                _processDays < _daysDiff(startDay, finalDay)
                )
            {

                link.processedDays =
                link.processedDays.add(_processDays);

                finalDay =
                startDay.add(_processDays);

            } else {

                link.isActive = false;
            }

        } else {

            _processDays = _daysDiff(startDay, _currentWiseDay());

            link.processedDays =
            link.processedDays.add(_processDays);

            finalDay =
            startDay.add(_processDays);
        }

        uint256 referralInterest = _checkReferralInterest(
            stake,
            startDay,
            finalDay
        );

        link.rewardAmount =
        link.rewardAmount.add(referralInterest);

        referrerLinks[_referrer][_referralID] = link;

        _mint(
            _referrer,
            referralInterest
        );

        emit ReferralCollected(
            staker,
            stakeID,
            _referrer,
            _referralID,
            referralInterest
        );
    }

    function checkReferralsByID(
        address _referrer,
        bytes16 _referralID
    )
        external
        view
        returns (
            address staker,
            bytes16 stakeID,
            uint256 referrerShares,
            uint256 referralInterest,
            bool isActiveReferral,
            bool isActiveStake,
            bool isMatureStake,
            bool isEndedStake
        )
    {
        ReferrerLink memory link = referrerLinks[_referrer][_referralID];

        staker = link.staker;
        stakeID = link.stakeID;
        isActiveReferral = link.isActive;

        Stake memory stake = stakes[staker][stakeID];
        referrerShares = stake.referrerShares;

        referralInterest = _checkReferralInterest(
            stake,
            _determineStartDay(stake, link),
            _determineFinalDay(stake)
        );

        isActiveStake = stake.isActive;
        isEndedStake = _stakeEnded(stake);
        isMatureStake = _isMatureStake(stake);
    }

    function _checkReferralInterest(Stake memory _stake, uint256 _startDay, uint256 _finalDay) internal view returns (uint256 _referralInterest) {
        return _notCriticalMassReferrer(_stake.referrer) ? 0 : _getReferralInterest(_stake, _startDay, _finalDay);
    }

    function _getReferralInterest(Stake memory _stake, uint256 _startDay, uint256 _finalDay) private view returns (uint256 _referralInterest) {
        for (uint256 _day = _startDay; _day < _finalDay; _day++) {
            _referralInterest += _stake.stakesShares * PRECISION_RATE / rsnapshots[_day].inflationAmount;
        }
    }

    function _determineStartDay(Stake memory _stake, ReferrerLink memory _link) internal view returns (uint256) {
        return (
            criticalMass[_stake.referrer].activationDay > _stake.startDay ?
            criticalMass[_stake.referrer].activationDay : _stake.startDay
        ).add(_link.processedDays);
    }

    function _determineFinalDay(
        Stake memory _stake
    )
        internal
        view
        returns (uint256)
    {
        return
            _stake.closeDay > 0 ?
            _stake.closeDay : _calculationDay(_stake);
    }
}