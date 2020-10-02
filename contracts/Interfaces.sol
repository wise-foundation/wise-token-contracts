// SPDX-License-Identifier: --🦉--

pragma solidity =0.7.2;

interface IWiseToken {

    function currentWiseDay()
        external view
        returns (uint64);

    function approve(
        address _spender,
        uint256 _value
    ) external returns (bool success);

    function mintSupply(
        address _investorAddress,
        uint256 _amount
    ) external;

    function giveStatus(
        address _referrer
    ) external;
}

interface UniswapRouterV2 {

    function addLiquidityETH(
        address token,
        uint256 amountTokenMax,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    );

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (
        uint256 amountB
    );

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (
        uint256[] memory amounts
    );
}

interface UniswapV2Pair {

    function getReserves() external view returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    );

    function token1() external view returns (address);
}

interface RefundSponsorI {
    function addGasRefund(address _a, uint256 _c) external;
}

interface IERC20Token {

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )  external returns (
        bool success
    );

    function approve(
        address _spender,
        uint256 _value
    )  external returns (
        bool success
    );
}