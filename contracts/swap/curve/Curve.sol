// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
pragma solidity =0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interface/IERC20.sol";

import "hardhat/console.sol";

interface IStablePairToken {
  function totalSupply() external virtual view returns (uint256);
  function mint(address _to, uint256 _value) external virtual returns (bool);
  function burnFrom(address _to, uint256 _value) external virtual returns (bool);
}

contract StablePair is IERC20, Ownable {
    // event Transfer(address indexed from, address indexed to, uint value);

  using SafeMath for uint;
  using SafeMath for uint256;

  uint public immutable FEE_DENOMINATOR = 10 ** 10;
  uint public immutable LENDING_PRECISION = 10 ** 18;
  uint public immutable PRECISION = 10 ** 18;  // # The precision to convert to
  uint public immutable FEE_INDEX = 2;         // Which coin may potentially have fees (USDT)
  uint public immutable MAX_ADMIN_FEE = 10 * 10 ** 9;
  uint public immutable MAX_FEE = 5 * 10 ** 9;
  uint public immutable MAX_A = 10 ** 6;
  uint public immutable MAX_A_CHANGE = 10;

  uint public immutable MIN_RAMP_TIME = 86400;

  // uint public N_COINS = 3;
  
  address public token0;
  address public token1;

  uint256 public PRECISION_MUL0; // = [1, 1000000000000, 1000000000000];
  uint256 public PRECISION_MUL1;
  uint256 public RATE0;
  uint256 public RATE1;

  uint256 public balance0;
  uint256 public balance1;

  uint256 public reserve0;
  uint256 public reserve1;

  uint256 public fee;
  uint256 public adminFee;
  uint256 public initialA;
  uint256 public futureA;
  uint256 public initialATime;
  uint256 public futureATime;


    string public constant override name = 'LP Token';
    string public constant override symbol = 'HMDX';
    uint8 public constant override decimals = 18;
  uint256 public override totalSupply;
      mapping(address => uint) public override balanceOf;
    mapping(address => mapping(address => uint)) public override allowance;
  // address rewardToken;

  constructor(address _tokenA,
              address _tokenB,
              uint _a,
              uint _fee,
              uint _precision0,
              uint _precision1
              ) {
    token0 = _tokenA;
    token1 = _tokenB;
    initialA = _a;
    futureA = _a;
    fee = _fee;

    // 初始化
    PRECISION_MUL0 = 1e18 / _precision0;
    PRECISION_MUL1 = 1e18 / _precision1;

    RATE0 = 1000000000000000000 * PRECISION_MUL0;
    RATE1 = 1000000000000000000 * PRECISION_MUL1;
  }
    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) override external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) override external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) override external returns (bool) {
        if (allowance[from][msg.sender] != uint(- 1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }
  /// Handle ramping A up or down 
  function _A() internal view returns (uint256) {
      uint256 t1 = futureATime;
    if (block.timestamp < t1) {
      uint256 A1 = futureA;
      uint256 A0 = initialA;
      uint256 t0 = initialATime;

      if (A1 > A0) {
        return A0 + (A1 - A0) * (block.timestamp - t0) / (t1 - t0);
      }
      return A0 - (A0 - A1) * (block.timestamp - t0) / (t1 - t0);
    }

    return futureA;
  }

  function _xp() internal view returns (uint256 r0, uint256 r1) {
    r0 = RATE0 * balance0 / LENDING_PRECISION;
    r1 = RATE1 * balance1 / LENDING_PRECISION;
  }

  function _xpMem(uint256 _b0, uint256 _b1) internal view returns (uint256 r0, uint256 r1) {
    r0 = RATE0 * _b0 / LENDING_PRECISION;
    r1 = RATE1 * _b1 / LENDING_PRECISION;
  }

  function _getD(uint256 xp0, uint256 xp1, uint256 amp) internal view returns (uint256) {
    uint256 S = xp0 + xp1;
    if (S == 0) {
      return 0;
    }

    uint256 Dprev = 0;
    uint256 D = S;
    uint256 Ann = amp * 2;
    for (uint i = 0; i < 255; i ++) {
      uint256 DP = D;
      // # If division by 0, this will be borked: only withdrawal will work. And that is good
      DP = DP * D / (2 * xp0);
      DP = DP * D / (2 * xp1);
      Dprev = D;
      D =  (Ann * S + DP * 2) * D / ((Ann - 1) * D + 3 * DP);

      console.log(i, Dprev, D);
      if (D > Dprev) {
        if (D - Dprev <= 1) break;
      } else {
        if (Dprev - D <= 1) break;
      }
    }
    return D;
  }

  function _getDMem(uint256 _b0, uint256 _b1, uint256 amp) internal view returns (uint256) {
    (uint256 xp0, uint256 xp1) = _xpMem(_b0, _b1);
    return _getD(xp0, xp1, amp);
  }

  function _getY(uint x0, uint x1, uint _xp0, uint _xp1) internal view returns (uint) {
    require(x0 != 0 || x1 != 0, "both 0");
    require(x0 == 0 || x1 == 0, "both not 0");

    uint amp = _A();
    uint D = _getD(_xp0, _xp1, amp);
    uint c = D;
    uint S = 0;
    uint Ann = 2 * amp;
    
    if (x0 == 0) {
      S = x1;
      c = D * D / (2 * x1);
    } else {
      S = x0;
      c = D * D / (2 * x0);
    }
    c = c * D / (Ann * 2);
    uint b = S + D / Ann;
    uint yPrev = 0;
    uint y = D;
    for (uint i = 0; i < 255; i ++) {
      yPrev = y;
      y = (y*y + c) / (2 * y + b - D);
      if (y > yPrev) {
        if (y - yPrev <= 1) break;
      } else {
        if (yPrev - y <= 1) break;
      }
    }
    return y;
  }

  function _getVirtualPrice() external view returns (uint256) {
    (uint256 b0, uint256 b1) = _xp();
    uint256 D = _getD(b0, b1, _A());

    return D * PRECISION / totalSupply;
  }

  function A() external view returns (uint256) {
    return _A();
  }

    // Simplified method to calculate addition or reduction in token supply at
    // deposit or withdrawal without taking fees into account (but looking at
    // slippage).
    // Needed to prevent front-running, not for precise calculations!
  function calcTokenAmount(uint amt0, uint amt1, bool deposit) external view returns (uint256) {
    uint _b0 = balance0;
    uint _b1 = balance1;
    uint amp = _A();
    uint D0 = _getDMem(_b0, _b1, amp);
    if (deposit) {
      _b0 += amt0;
      _b1 += amt1;
    } else {
      _b0 -= amt0;
      _b1 -= amt1;
    }
    uint D1 = _getDMem(_b0, _b1, amp);
    uint diff;
    if (deposit) {
      diff = D1 - D0;
    } else {
      diff = D0 - D1;
    }
    return diff * totalSupply / D0;
  }

  function _update(uint balance0, uint balance1) private {
        require(balance0 <= uint112(- 1) && balance1 <= uint112(- 1), 'DeBankSwap: OVERFLOW');

        reserve0 = uint256(balance0);
        reserve1 = uint256(balance1);
    }
  function _mint(address to, uint value) internal {

        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

  function addLiquidity() external returns (uint) {
    // uint _fee = fee / 2;
    uint amp = _A();
    uint D0 = 0;
    // todo
    (uint _r0, uint _r1) = getReserves();
    // uint _r0 = balance0;  // old balance0
    // uint _r1 = balance1;  // old balance1
    uint balance0 = IERC20(token0).balanceOf(address(this));
    uint balance1 = IERC20(token1).balanceOf(address(this));
    
    // uint amt0;
    // uint amt1;
    if (totalSupply > 0) {
      D0 = _getDMem(_r0, _r1, amp);
    } else {
      require(balance0 > _r0 || balance1 > _r1, "both 0");
      // require(balance1 > _r1, "amt1 0");
      // amt0 = balance0 - _r0;
      // amt1 = balance1 - _r1;
    }

    uint D1 = _getDMem(balance0, balance1, amp);
    uint mintAmt;
    require(D1 > D0, "D1 <= D0");
    if (totalSupply > 0) {
      // 不收管理费
      mintAmt = totalSupply * (D1 - D0) / D0;
    } else {
      mintAmt = D1;
    }

    console.log("mint: %d", mintAmt);

    _mint(msg.sender, mintAmt);
    _update(balance0, balance1);

    return mintAmt;
  }

  function getDy(uint amt0, uint amt1) external view returns (uint) {
    (uint xp0, uint xp1) = _xp();
    uint rate0 = RATE0;
    uint rate1 = RATE1;

    uint dy;
    if (amt0 > 0) {
      uint x = xp0 + amt0 * rate0 / PRECISION;
      uint y = _getY(x, 0, xp0, xp1);
      dy = (xp1 - y -1) * PRECISION / rate1;
    } else {
      require(amt1 > 0, "both 0");
      uint x = xp1 + amt1 * rate1 / PRECISION;
      uint y = _getY(0, x, xp0, xp1);
      dy = (xp0 - y - 1) * PRECISION / rate0;
    }

    uint _fee = fee * dy / FEE_DENOMINATOR;
    return dy;
  }

  // # dx and dy in underlying units
  function getDyUnderlying(uint amt0, uint amt1) external view returns (uint) {
    (uint xp0, uint xp1) = _xp();

    uint dy;
    if (amt0 > 0) {
      uint x = xp0 + amt0 * PRECISION_MUL0;
      uint y = _getY(x, 0, xp0, xp1);
      dy = (xp1 - y -1) * PRECISION_MUL1;
    } else {
      require(amt1 > 0, "both 0");
      uint x = xp1 + amt1 * PRECISION_MUL1;
      uint y = _getY(0, x, xp0, xp1);
      dy = (xp0 - y - 1) * PRECISION_MUL0;
    }

    uint _fee = fee * dy / FEE_DENOMINATOR;
    return dy;
  }

  function getReserves() public view returns (uint, uint) {
    return (reserve0, reserve1);
  }

  // swap
  function swap(uint minAmt0, uint minAmt1, address to) public {
    (uint r0, uint r1) = getReserves();
    (uint xp0, uint xp1) = _xpMem(r0, r1);

    console.log("swap:", r0, r1);

    uint balance0 = IERC20(token0).balanceOf(address(this));
    uint balance1 = IERC20(token1).balanceOf(address(this));
    console.log("balance:", balance0, balance1);

    if (balance0 > r0) {
      uint amt0 = balance0 - r0;
      uint x = xp0 + amt0 * RATE0 / PRECISION;
      uint y = _getY(x, 0, xp0, xp1);
      uint dy = xp1 - y - 1;
      uint dyFee = dy * fee / FEE_DENOMINATOR;

      dy = (dy - dyFee) * PRECISION / RATE1;
      require(dy > minAmt1, "dy less minAmt1");
      console.log("swap dy:", dy);

      IERC20(token1).transfer(to, dy);
      balance1 = IERC20(token1).balanceOf(address(this));
    } else {
      uint amt1 = balance1 - r1;
      require(amt1 > 0, "both 0");
      console.log("amount1:", amt1);
      uint y = xp1 + amt1 * RATE1 / PRECISION;
      uint x = _getY(0, y, xp0, xp1);
      uint dx = xp0 - x - 1;
      uint dxFee = dx * fee / FEE_DENOMINATOR;

      dx = (dx - dxFee) * PRECISION / RATE0;
      require(dx > minAmt0, "dx less minAmt1");
      console.log("swap dx:", dx);
      IERC20(token0).transfer(to, dx);
    }
    
    _update(balance0, balance1);
  }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        // emit Transfer(from, address(0), value);
    }
  function removeLiquidity(address from) external {
    uint amt = balanceOf[address(this)];
    uint b0 = IERC20(token0).balanceOf(address(this));
    uint b1 = IERC20(token1).balanceOf(address(this));

    uint amt0 = b0 * amt / totalSupply;
    uint amt1 = b1 * amt / totalSupply;
    // transfer
    console.log("balance:", b0, b1, totalSupply);
    console.log("burn:", amt, amt0, amt1);
    IERC20(token0).transfer(from, amt0);
    IERC20(token1).transfer(from, amt1);

    // burn
    _burn(address(this), amt);

    b0 = IERC20(token0).balanceOf(address(this));
    b1 = IERC20(token1).balanceOf(address(this));
    console.log("after burn, balance:", b0, b1);
    _update(b0, b1);
  }
}
