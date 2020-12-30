// SPDX-License-Identifier: --🦉--

pragma solidity =0.7.6;

import "./Declaration.sol";

abstract contract Timing is Declaration {

    function currentWiseDay() public view returns (uint64) {
        return _getNow() >= LAUNCH_TIME ? _currentWiseDay() : 0;
    }

    function _currentWiseDay() internal view returns (uint64) {
        return _wiseDayFromStamp(_getNow());
    }

    function _nextWiseDay() internal view returns (uint64) {
        return _currentWiseDay() + 1;
    }

    function _previousWiseDay() internal view returns (uint64) {
        return _currentWiseDay() - 1;
    }

    function _wiseDayFromStamp(uint256 _timestamp) internal view returns (uint64) {
        return uint64((_timestamp - LAUNCH_TIME) / SECONDS_IN_DAY);
    }

    function _getNow() internal view returns (uint256) {
        return block.timestamp;
    }
}