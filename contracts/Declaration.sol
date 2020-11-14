// SPDX-License-Identifier: --🦉--

pragma solidity =0.7.4;

import "./Global.sol";

interface IUniswapV2Factory {

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (
        address pair
    );
}

interface IUniswapRouterV2 {

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (
        uint[] memory amounts
    );

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (
        uint[] memory amounts
    );

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadlin
    ) external payable returns (
        uint[] memory amounts
    );
}

interface IUniswapV2Pair {

    function getReserves() external view returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    );

    function transfer(
        address to,
        uint256 value
    ) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function balanceOf(
        address owner
    ) external view returns (uint256);

    function token1() external view returns (address);
    function totalSupply() external view returns (uint256);
}

interface ILiquidityGuard {
    function getInflation(uint32 _amount) external view returns (uint256);
}

interface ERC20TokenI {

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

abstract contract Declaration is Global {

    uint256 constant _decimals = 18;
    uint256 constant YODAS_PER_WISE = 10 ** _decimals;

    // uint32 constant SECONDS_IN_DAY = 86400 seconds;
    uint16 constant SECONDS_IN_DAY = 30 seconds;
    uint16 constant MIN_LOCK_DAYS = 1;
    uint16 constant FORMULA_DAY = 65;
    uint16 constant MAX_LOCK_DAYS = 15330;
    uint16 constant MAX_BONUS_DAYS_A = 1825;
    uint16 constant MAX_BONUS_DAYS_B = 13505;
    uint16 constant MIN_REFERRAL_DAYS = 365;

    uint32 constant MIN_STAKE_AMOUNT = 1000000;
    uint32 constant REFERRALS_RATE = 366816973; // 1.000% (direct value, can be used right away)
    uint32 constant INFLATION_RATE_MAX = 103000; // 3.000% (indirect -> checks throgh LiquidityGuard)

    uint32 public INFLATION_RATE = 103000; // 3.000% (indirect -> checks throgh LiquidityGuard)
    uint32 public LIQUIDITY_RATE = 100006; // 0.006% (indirect -> checks throgh LiquidityGuard)

    uint64 constant PRECISION_RATE = 1E18;

    uint96 constant THRESHOLD_LIMIT = 10000E18; // $10,000 DAI

    uint96 constant DAILY_BONUS_A = 13698630136986302; // 25%:1825 = 0.01369863013 per day;
    uint96 constant DAILY_BONUS_B = 370233246945575;   // 5%:13505 = 0.00037023324 per day;

    uint256 immutable LAUNCH_TIME;

    // address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant DAI = 0xaD6D458402F60fD3Bd25163575031ACDce07538D; // ropsten

    // address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // mainnet
    // address constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab; // ropsten
    address constant WETH = 0xEb59fE75AC86dF3997A990EDe100b90DDCf9a826; // local

    IUniswapRouterV2 public constant UNISWAP_ROUTER = IUniswapRouterV2(
        // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D // mainnet
        // 0xf164fC0Ec4E93095b804a4795bBe1e041497b92a // ropsten
        0x57079e0d0657890218C630DA5248A1103a1b4ad0 // local
    );

    IUniswapV2Factory public constant UNISWAP_FACTORY = IUniswapV2Factory(
        // 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f // mainnet
        // 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f // ropsten
        0xd627ba3B9D89b99aa140BbdefD005e8CdF395a25 // local
    );

    ILiquidityGuard public constant LIQUIDITY_GUARD = ILiquidityGuard(
        // 0x9C306CaD86550EC80D77668c0A8bEE6eB34684B6 // mainnet
        // 0x0C914aAE959e3099815e373d94DFfBA5F9E0Fdf8 // ropsten
        0xEeAd57F022Af8f6b2544BFE7A39C80CdCFe07E4E // local
    );

    IUniswapV2Pair public UNISWAP_PAIR;
    bool public isLiquidityGuardActive;

    uint256 public latestDaiEquivalent;
    address[] internal _path = [address(this), WETH, DAI];

    constructor() {
        // LAUNCH_TIME = 1605052800; // (11th November 2020 @00:00 GMT == day 0)
        // LAUNCH_TIME = 1604966400; // (10th November 2020 @00:00 GMT == day 0)
        LAUNCH_TIME = block.timestamp;
    }

    function createPair() external {
        UNISWAP_PAIR = IUniswapV2Pair(
            UNISWAP_FACTORY.createPair(
                WETH, address(this)
            )
        );
    }

    struct Stake {
        uint256 stakesShares;
        uint256 stakedAmount;
        uint256 rewardAmount;
        uint64 startDay;
        uint64 lockDays;
        uint64 finalDay;
        uint64 closeDay;
        uint256 scrapeDay;
        uint256 daiEquivalent;
        uint256 referrerShares;
        address referrer;
        bool isActive;
    }

    struct ReferrerLink {
        address staker;
        bytes16 stakeID;
        uint256 rewardAmount;
        uint256 processedDays;
        bool isActive;
    }

    struct LiquidityStake {
        uint256 stakedAmount;
        uint256 rewardAmount;
        uint64 startDay;
        uint64 closeDay;
        bool isActive;
    }

    struct CriticalMass {
        uint256 totalAmount;
        uint256 activationDay;
    }

    mapping(address => uint256) public stakeCount;
    mapping(address => uint256) public referralCount;
    mapping(address => uint256) public liquidityStakeCount;

    mapping(address => CriticalMass) public criticalMass;
    mapping(address => mapping(bytes16 => Stake)) public stakes;
    mapping(address => mapping(bytes16 => ReferrerLink)) public referrerLinks;
    mapping(address => mapping(bytes16 => LiquidityStake)) public liquidityStakes;

    mapping(uint256 => uint256) public scheduledToEnd;
    mapping(uint256 => uint256) public referralSharesToEnd;
    mapping(uint256 => uint256) public totalPenalties;
}
