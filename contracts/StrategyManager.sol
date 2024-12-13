// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title StrategyManager
/// @author HyperLend
/// @notice contract used to manage custom strategy on behalf of the user
contract StrategyManager is Ownable {
    address public pool;
    address public yieldAsset;
    address public debtAsset;

    constructor(
        address _owner,
        address _pool,
        address _yieldAsset,
        address _debtAsset
    ) Ownable(_owner){
        pool = _pool;
        yieldAsset = _yieldAsset;
        debtAsset = _debtAsset;
    }

    function executeCall(address target, uint256 value, bytes memory data, bool allowRevert) public onlyOwner() returns (bytes memory) {
        (bool success, bytes memory returnData) = target.call{value: value}(data);
        if (!allowRevert) require(success, 'execution reverted');
        return returnData;
    }

    function executeMultiCall(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory data,
        bool[] memory allowReverts
    ) external onlyOwner() {
        for (uint256 i  = 0; i < targets.length; i++){
            executeCall(targets[i], values[i], data[i], allowReverts[i]);
        }
    }
}