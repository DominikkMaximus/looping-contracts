// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { PositionsManager } from "./PositionsManager.sol";

contract PositionsManagerFactory is Ownable {
    /// @notice mapping of user => positionManager contract
    mapping(address => address) public userPositionManagers;

    uint256 public length;

    event PositionManagerCreated(address indexed owner, address indexed positionManager);

    constructor() Ownable(msg.sender){}

    function createPositionManager() external {
        require(userPositionManagers[msg.sender] == address(0), "positionManager already created");

        PositionsManager _posManager = new PositionsManager(msg.sender);
        userPositionManagers[msg.sender] = address(_posManager);
        length++;

        emit PositionManagerCreated(msg.sender, address(_posManager));
    }

    function getPositionManager(address _user) external view returns (address){
        return userPositionManagers[_user];
    }
}