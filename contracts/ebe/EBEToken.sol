// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract EbeToken is ERC20, Ownable {
    string public name;
    string public symbol;
    uint8 public decimals;

    address public minter;
    // The block number when EBE mining starts.
    uint256 public startBlock;
    // How many blocks are halved
    uint256 public halvingPeriod = 5256000;

    constructor () public {
        name = "EBE Token";
        symbol = "EBE";
        decimals = 18;
    }

    // modifier for mint function
    modifier onlyMinter() {
        require(msg.sender == minter, "caller is not the minter");
        _;
    }

    function setHalvingPeriod(uint256 _block) public onlyMinter {
        halvingPeriod = _block;
    }

    // mint with max supply
    function mint(address _to, uint256 _amount) public onlyMinter returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    function setMinter(address _newMinter) external {
        require(minter == address(0), "has set up");
        require(_newMinter != address(0), "is zero address");
        minter = _newMinter;
    }

    // At what phase
    function phase(uint256 blockNumber) public view returns (uint256) {
        if (halvingPeriod == 0) {
            return 0;
        }

        if (blockNumber > startBlock) {
            return (blockNumber.sub(startBlock).sub(1)).div(halvingPeriod);
        }
        return 0;
    }

    function phase() public view returns (uint256) {
        return phase(block.number);
    }

    function reward(uint256 ebePerBlock, uint256 blockNumber) public view returns (uint256) {
        uint256 _phase = phase(blockNumber);
        return ebePerBlock.div(2 ** _phase);
    }

    function reward(uint256 ebePerBlock) public view returns (uint256) {
        return reward(ebePerBlock, block.number);
    }

    // set start block
    function setStartBlock(uint256 start) public onlyOwner {
        startBlock = start;
    }

    // Rewards for the current block
    function getEbeReward(uint256 ebePerBlock, uint256 _lastRewardBlock) public view returns (uint256) {
        require(_lastRewardBlock <= block.number, "EBEToken: must little than the current block number");
        uint256 blockReward = 0;
        uint256 n = phase(_lastRewardBlock);
        uint256 m = phase(block.number);
        // If it crosses the cycle
        while (n < m) {
            n++;
            // Get the last block of the previous cycle
            uint256 r = n.mul(halvingPeriod).add(startBlock);
            // Get rewards from previous periods
            blockReward = blockReward.add((r.sub(_lastRewardBlock)).mul(reward(ebePerBlock, r)));
            _lastRewardBlock = r;
        }
        blockReward = blockReward.add((block.number.sub(_lastRewardBlock)).mul(reward(block.number)));
        return blockReward;
    }

}
