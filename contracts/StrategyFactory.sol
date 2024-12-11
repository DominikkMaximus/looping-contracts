// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { StrategyManager } from "./StrategyManager.sol";

contract StrategyManagerFactory is Ownable {
    /// @notice mapping of user => StrategyManager contract
    mapping(address => address[]) public userStrategies;
    /// @notice mapping of user => strategyId => exists
    mapping(address => mapping(bytes32 => bool)) public existingStrategies;

    event StrategyDeployed(address indexed owner, address indexed stratManager, address pool, address yieldAsset, address debtAsset);

    constructor() Ownable(msg.sender){}

    function createStrategyManager(address _pool, address _yieldAsset, address _debtAsset) external {
        require(existingStrategies[msg.sender][getStrategyId(_pool, _yieldAsset, _debtAsset)] == false, "strategy already exists");

        StrategyManager _stratManager = new StrategyManager(msg.sender);
        userStrategies[msg.sender].push(address(_stratManager));
        existingStrategies[msg.sender][getStrategyId(_pool, _yieldAsset, _debtAsset)] = true;

        emit StrategyDeployed(msg.sender, address(_stratManager), _pool, _yieldAsset, _debtAsset);
    }

    /// @notice combine the pool, yieldAsset and debtAsset addresses and hash them
    function getStrategyId(address pool, address yieldAsset, address debtAsset) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(pool, yieldAsset, debtAsset));
    }
}