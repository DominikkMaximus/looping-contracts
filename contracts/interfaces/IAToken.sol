// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAToken {
    function scaledBalanceOf(address user) external returns (uint256);
}