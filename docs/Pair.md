
interface IDeBankPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    // 发行量
    function totalSupply() external view returns (uint);

    // 余额
    function balanceOf(address owner) external view returns (uint);

    // function ownerAmountOf(address owner) external view returns (uint);

    // 授权
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    // 转账
    function transfer(address to, uint value) external returns (bool);

    // 转账
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);

    function factory() external view returns (address);

    function feeRate() external view returns (uint);

    // 交易对的token0
    function token0() external view returns (address);

    // 交易对的token1
    function token1() external view returns (address);

    // pair 合约持有的 token0 token1 的数量
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    // 提供流动性, 调用前需要把 token0 token1 转到 pair合约
    function mint(address to) external returns (uint liquidity);
    // function mintCToken(address to) external returns (uint liquidity);

    // 移除流动性, 调用前需要把LP转到 pair 合约
    function burn(address to) external returns (uint amount0, uint amount1);

    // 兑换
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

    // 兑换
    function swapNoFee(uint amount0Out, uint amount1Out, address to, uint fee) external;

    function skim(address to) external;

    function sync() external;

    function price(address token, uint256 baseDecimal) external view returns (uint256);

    function initialize(address, address, address, address) external;
    function updateFeeRate(uint256 _feeRate) external;
    // initialize ctoken address
    // function initializeCTokenAddress(address, address) external;

    function getFee(uint256 amt) external view returns (uint256);

    // function updateFeeRate(_feeRate) external;
}
