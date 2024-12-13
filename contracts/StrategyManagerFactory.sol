// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { StrategyManager } from "./StrategyManager.sol";

/// @title StrategyManagerFactory
/// @author HyperLend
/// @notice factory contract used to create strategyManager contracts for users
contract StrategyManagerFactory is Ownable {
    /// @notice mapping of user => StrategyManager contract
    mapping(address => address[]) public userStrategies;
    /// @notice mapping of user => strategyId => exists
    mapping(address => mapping(bytes32 => bool)) public existingStrategies;

    /// @notice event emitted when new StrategyManager contract is created
    event StrategyDeployed(address indexed owner, address indexed stratManager, address pool, address yieldAsset, address debtAsset);

    constructor() Ownable(msg.sender){}

    /// @notice create a new strategyManager contract for the user
    /// @param _pool address of the lending pool to supply/borrow from
    /// @param _yieldAsset address of the asset to be supplied
    /// @param _debtAsset address of the asset to be borrowed
    function createStrategyManager(address _pool, address _yieldAsset, address _debtAsset) external {
        require(existingStrategies[msg.sender][getStrategyId(_pool, _yieldAsset, _debtAsset)] == false, "strategy already exists");

        StrategyManager _stratManager = new StrategyManager(msg.sender, _pool, _yieldAsset, _debtAsset);
        userStrategies[msg.sender].push(address(_stratManager));
        existingStrategies[msg.sender][getStrategyId(_pool, _yieldAsset, _debtAsset)] = true;

        emit StrategyDeployed(msg.sender, address(_stratManager), _pool, _yieldAsset, _debtAsset);
    }

    /// @notice combine the pool, yieldAsset and debtAsset addresses and hash them
    function getStrategyId(address pool, address yieldAsset, address debtAsset) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(pool, yieldAsset, debtAsset));
    }

    /// @notice get all users strategyManager addresses
    function getUserStrategyManagers(address _user) external view returns (address[] memory) {
        return userStrategies[_user];
    }
}