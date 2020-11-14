// SPDX-License-Identifier: --🦉--

pragma solidity =0.7.4;

import "./Timing.sol";

abstract contract Helper is Timing {

    using SafeMath for uint256;

    function notContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size == 0);
    }

    function toBytes16(uint256 x) internal pure returns (bytes16 b) {
       return bytes16(bytes32(x));
    }

    function generateID(address x, uint256 y, bytes1 z) public pure returns (bytes16 b) {
        b = toBytes16(
            uint256(
                keccak256(
                    abi.encodePacked(x, y, z)
                )
            )
        );
    }

    function generateStakeID(address _staker) internal view returns (bytes16 stakeID) {
        return generateID(_staker, stakeCount[_staker], 0x01);
    }

    function generateReferralID(address _referrer) internal view returns (bytes16 referralID) {
        return generateID(_referrer, referralCount[_referrer], 0x02);
    }

    function generateLiquidityStakeID(address _staker) internal view returns (bytes16 liquidityStakeID) {
        return generateID(_staker, liquidityStakeCount[_staker], 0x03);
    }

    function activeStakesCount(
        address _staker
    )
        external
        view
        returns (
            uint256 activeCount
        )
    {
        for (uint256 _stakeIndex = 0; _stakeIndex <= stakeCount[_staker]; _stakeIndex++) {
            bytes16 _stakeID = generateID(_staker, _stakeIndex - 1, 0x01);
            if (stakes[_staker][_stakeID].isActive) {
                activeCount++;
            }
        }
    }

    function activeReferralCount(
        address _referrer
    )
        external
        view
        returns (
            uint256 activeCount
        )
    {
        for (uint256 _rIndex = 0; _rIndex <= referralCount[_referrer]; _rIndex++) {
            bytes16 _rID = generateID(_referrer, _rIndex - 1, 0x02);
            if (referrerLinks[_referrer][_rID].isActive) {
                activeCount++;
            }
        }
    }

    function stakesPagination(
        address _staker,
        uint256 _offset,
        uint256 _length
    )
        external
        view
        returns (bytes16[] memory _stakes)
    {
        uint256 start = _offset > 0 &&
            stakeCount[_staker] > _offset ?
            stakeCount[_staker] - _offset : stakeCount[_staker];

        uint256 finish = _length > 0 &&
            start > _length ?
            start - _length : 0;

        uint256 i;

        _stakes = new bytes16[](start - finish);

        for (uint256 _stakeIndex = start; _stakeIndex > finish; _stakeIndex--) {
            bytes16 _stakeID = generateID(_staker, _stakeIndex - 1, 0x01);
            if (stakes[_staker][_stakeID].stakedAmount > 0) {
                _stakes[i] = _stakeID; i++;
            }
        }
    }

    function referralsPagination(
        address _referrer,
        uint256 _offset,
        uint256 _length
    )
        external
        view
        returns (bytes16[] memory _referrals)
    {
        uint256 start = _offset > 0 &&
            referralCount[_referrer] > _offset ?
            referralCount[_referrer] - _offset : referralCount[_referrer];

        uint256 finish = _length > 0 &&
            start > _length ?
            start - _length : 0;

        uint256 i;

        _referrals = new bytes16[](start - finish);

        for (uint256 _rIndex = start; _rIndex > finish; _rIndex--) {
            bytes16 _rID = generateID(_referrer, _rIndex - 1, 0x02);
            if (_nonZeroAddress(referrerLinks[_referrer][_rID].staker)) {
                _referrals[i] = _rID; i++;
            }
        }
    }

    function latestStakeID(address _staker) external view returns (bytes16) {
        return stakeCount[_staker] == 0 ? bytes16(0) : generateID(_staker, stakeCount[_staker].sub(1), 0x01);
    }

    function latestReferralID(address _referrer) external view returns (bytes16) {
        return referralCount[_referrer] == 0 ? bytes16(0) : generateID(_referrer, referralCount[_referrer].sub(1), 0x02);
    }

    function latestLiquidityStakeID(address _staker) external view returns (bytes16) {
        return liquidityStakeCount[_staker] == 0 ? bytes16(0) : generateID(_staker, liquidityStakeCount[_staker].sub(1), 0x03);
    }

    function _increaseStakeCount(address _staker) internal {
        stakeCount[_staker] = stakeCount[_staker] + 1;
    }

    function _increaseReferralCount(address _referrer) internal {
        referralCount[_referrer] = referralCount[_referrer] + 1;
    }

    function _increaseLiquidityStakeCount(address _staker) internal {
        liquidityStakeCount[_staker] = liquidityStakeCount[_staker] + 1;
    }

    function _isMatureStake(Stake memory _stake) internal view returns (bool) {
        return _stake.finalDay <= globals.currentWiseDay;
    }

    function _notCriticalMassReferrer(address _referrer) internal view returns (bool) {
        return criticalMass[_referrer].activationDay == 0;
    }

    function _stakeNotStarted(Stake memory _stake) internal view returns (bool) {
        return _stake.startDay > globals.currentWiseDay;
    }

    function _stakeEnded(Stake memory _stake) internal view returns (bool) {
        return _stake.isActive == false || _isMatureStake(_stake);
    }

    function _daysLeft(Stake memory _stake) internal view returns (uint256) {
        return _stakeEnded(_stake) ? 0 : _daysDiff(_currentWiseDay(), _stake.finalDay);
    }

    function _daysDiff(uint256 _startDate, uint256 _endDate) internal pure returns (uint256) {
        return _startDate > _endDate ? 0 : _endDate.sub(_startDate);
    }

    function _calculationDay(Stake memory _stake) internal view returns (uint256) {
        return _stake.finalDay > globals.currentWiseDay ? globals.currentWiseDay : _stake.finalDay;
    }

    function _startingDay(Stake memory _stake) internal pure returns (uint256) {
        return _stake.scrapeDay == 0 ? _stake.startDay : _stake.scrapeDay;
    }

    function _notFuture(uint256 _day) internal view returns (bool) {
        return _day <= _currentWiseDay();
    }

    function _notPast(uint256 _day) internal view returns (bool) {
        return _day >= _currentWiseDay();
    }

    function _nonZeroAddress(address _address) internal pure returns (bool) {
        return _address != address(0x0);
    }

    function _getLockDays(Stake memory _stake) internal pure returns (uint256) {
        return
            _stake.lockDays > 1 ?
            _stake.lockDays - 1 : 1;
    }

    function _preparePath(
        address _tokenAddress,
        address _wiseAddress
    )
        internal
        pure
        returns (address[] memory _path)
    {
        _path = new address[](3);
        _path[0] = _tokenAddress;
        _path[1] = WETH;
        _path[2] = _wiseAddress;
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    )
        internal
    {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                0xa9059cbb,
                to,
                value
            )
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool)))
            // 'WISE: transfer failed'
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint value
    )
        internal
    {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                0x23b872dd,
                from,
                to,
                value
            )
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool)))
            // 'WISE: transferFrom failed'
        );
    }
}