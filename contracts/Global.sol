// SPDX-License-Identifier: --🦉--

pragma solidity =0.7.4;

import "./ERC20.sol";
import "./Events.sol";

abstract contract Global is ERC20, Events {

    using SafeMath for uint256;

    struct Globals {
        uint256 totalStaked;
        uint256 totalShares;
        uint256 sharePrice;
        uint256 currentWiseDay;
        uint256 referralShares;
    }

    Globals public globals;

    constructor() {
        globals.sharePrice = 100E15;
    }

    function _increaseGlobals(
        uint256 _staked,
        uint256 _shares,
        uint256 _rshares
    )
        internal
    {
        globals.totalStaked =
        globals.totalStaked.add(_staked);

        globals.totalShares =
        globals.totalShares.add(_shares);

        if (_rshares > 0) {

            globals.referralShares =
            globals.referralShares.add(_rshares);
        }

        _logGlobals();
    }

    function _decreaseGlobals(
        uint256 _staked,
        uint256 _shares,
        uint256 _rshares
    )
        internal
    {
        globals.totalStaked =
        globals.totalStaked > _staked ?
        globals.totalStaked - _staked : 0;

        globals.totalShares =
        globals.totalShares > _shares ?
        globals.totalShares - _shares : 0;

        if (_rshares > 0) {

            globals.referralShares =
            globals.referralShares > _rshares ?
            globals.referralShares - _rshares : 0;

        }

        _logGlobals();
    }

    function _logGlobals()
        private
    {
        emit NewGlobals(
            globals.totalShares,
            globals.totalStaked,
            globals.sharePrice,
            globals.currentWiseDay,
            globals.referralShares
        );
    }
}