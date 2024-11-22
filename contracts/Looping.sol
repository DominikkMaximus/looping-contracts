// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { ISwapper } from "./interfaces/ISwapper.sol";
import { IPool } from "./interfaces/IPool.sol";

/// @title Looping
/// @author HyperLend
/// @notice Contract used to open leveraged positions on HyperLend
contract Looping is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice mapping of whitelisted lending pools
    mapping(address => bool) public pools;
    /// @notice mapping of whitelisted swapper contracts
    mapping(address => bool) public swappers;

    /// @param _pools array of whitelisted pools
    /// @param _swappers array of whitelisted swappers
    constructor(address[] memory _pools, address[] memory _swappers, address _owner) Ownable(_owner) {
        for (uint256 i = 0; i < _pools.length; i++){
            pools[_pools[i]] = true;
        }
        for (uint256 i = 0; i < _swappers.length; i++){
            swappers[_swappers[i]] = true;
        }
    }

    /// @param _pool address of the pool we want to supply/borrow from
    /// @param _swapper address of the swapping contract (DEX) used to swap _debtAsset to _yieldAsset
    /// @param _debtAsset asset we want to borrow
    /// @param _yieldAsset asset we want to maximize the supply
    /// @param _initialAmount initial amount of the _debtAsset provided by the user
    /// @param _flashloanAmount amount of the _debtAsset we want to flashloan and then swap to _yieldAsset
    /// @param _minAmountOut minimum amount of _yieldAsset we can receive after swapping _debtAsset
    /// @param _path path used to swap from _debtAsset to _yieldAsset
    function leverage(
        address _pool, 
        address _swapper,
        address _debtAsset, 
        address _yieldAsset, 
        uint256 _initialAmount, 
        uint256 _flashloanAmount, 
        uint256 _minAmountOut,
        address[] memory _path
    ) external nonReentrant() {
        require(pools[_pool], "pool not allowed");

        //transfer initial _debtAsset from user
        IERC20(_debtAsset).transferFrom(msg.sender, address(this), _initialAmount);

        //use flashloan to borrow _debtAsset
        uint256 repaymentAmount = _flashloanAmount - _initialAmount;
        bytes memory params = abi.encode(_yieldAsset, _swapper, _path, repaymentAmount, _minAmountOut);
        IPool(_pool).flashLoanSimple(address(this), _debtAsset, _flashloanAmount, params, 0);
    }

    /// @notice callback function called by pool contract during flashloan
    /// @param debtAsset asset we received from the flashloan
    /// @param amount amount of the debtAsset we received from the flashloan
    /// @param premium flashloan premium we must repay
    /// @param initiator address of the flashloan initiator
    /// @param params extra data passed to us by the pool contract
    function executeOperation(
        address debtAsset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    )  external returns (bool) {
        require(pools[msg.sender], "msg.sender != pool");
        require(initiator == address(this), "initiator != address(this)");

        (
            address yieldAsset, 
            address swapper, 
            address[] memory path, 
            uint256 repaymentAmount,
            uint256 minAmountOut
        ) = abi.decode(params, (address, address, address[], uint256, uint256));

        //swap flashloaned debt token to yield token
        uint256 yieldAmount = _swapToYield(swapper, path, amount, minAmountOut);

        //supply yield tokens, borrow debt tokens
        _supplyAndBorrow(debtAsset, yieldAsset, yieldAmount, repaymentAmount + premium);

        //refund any leftover assets that would remain in the contract after flashloan repayment
        _refund(debtAsset, yieldAsset, amount, premium);

        //approve pool so it can pull the funds to repay the flashloan
        IERC20(debtAsset).approve(msg.sender, amount + premium);

        return true;
    }

    /// @notice used to swap debt token to yield token
    /// @param swapper address of the dex contract
    /// @param path path we want to use when swapping
    /// @param minAmountOut minimum amount fo yield token we want to receive
    function _swapToYield(address swapper, address[] memory path, uint256 amountToSwap, uint256 minAmountOut) internal returns (uint256) {
        require(swappers[swapper], "swapper not allowed");

        IERC20(path[0]).approve(swapper, amountToSwap);

        uint256 balanceBefore = IERC20(path[path.length-1]).balanceOf(address(this));
        ISwapper(swapper).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountToSwap,
            minAmountOut,
            path,
            address(this),
            owner(),
            block.timestamp
        );
        uint256 balanceAfter = IERC20(path[path.length-1]).balanceOf(address(this));

        return balanceAfter - balanceBefore;
    }

    /// @notice used to supply yield token to the pool and borrow debt token
    /// @param debtAsset address of the token we want to borrow
    /// @param yieldAsset address of the token we want to supply
    /// @param yieldAmount amount of the yield token we want to supply
    /// @param repaymentAmount amount of the debt asset we want to borrow (so we can repay the flashloan)
    function _supplyAndBorrow(address debtAsset, address yieldAsset, uint256 yieldAmount, uint256 repaymentAmount) internal {
        //supply yield token
        //note: msg.sender is now pool
        IERC20(yieldAsset).approve(msg.sender, yieldAmount);
        IPool(msg.sender).supply(yieldAsset, yieldAmount, tx.origin, 0);

        //borrow debt token, so we have enough to repay the flashloan
        IPool(msg.sender).borrow(debtAsset, repaymentAmount, 2, 0, tx.origin);
    }

    /// @notice used to refund any tokens that would remain in the contract after the flashloan repayment
    /// @param debtAsset address of the token we want to borrow
    /// @param yieldAsset address of the token we want to supply
    /// @param amount amount of the debt token we owe from the flashloan
    /// @param premium amount of the premium we need to pay for the flashloan
    function _refund(address debtAsset, address yieldAsset, uint256 amount, uint256 premium) internal {
        uint256 debtAssetBalance = IERC20(debtAsset).balanceOf(address(this));
        uint256 yieldAssetBalance = IERC20(yieldAsset).balanceOf(address(this));

        if (debtAssetBalance > amount + premium){
            IERC20(debtAsset).transfer(tx.origin, debtAssetBalance - (amount + premium));
        }
        if (yieldAssetBalance > 0){
            IERC20(yieldAsset).transfer(tx.origin, yieldAssetBalance);
        }
    }

    
    /// @notice used to add or remove pools from the whitelist
    function setPool(address _pool, bool _isApproved) external onlyOwner(){
        pools[_pool] = _isApproved;
    }

    /// @notice used to add or remove swappers from the whitelist
    function setSwapper(address _swapper, bool _isApproved) external onlyOwner(){
        swappers[_swapper] = _isApproved;
    }

    /// @notice used to rescue stuck tokens that were sent to the contract by mistake
    function rescueTokens(address token, uint256 amount) external onlyOwner() {
        if (token == address(0)){
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "transfer failed");
        } else {
            IERC20(token).transfer(msg.sender, amount);
        }
    }
}
