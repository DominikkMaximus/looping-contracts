// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { ILiquidSwap } from "../interfaces/ILiquidSwap.sol";
import { IWrappedHlpDepositor } from '../interfaces/IWrappedHlpDepositor.sol';

/// @title wHlpZapper
/// @author HyperLend
/// @notice Contract used to swap tokens to USDT0 before depositing them to wHLP
contract wHlpZapper is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /// @notice liquid swap router
    ILiquidSwap public liquidSwapRouter = ILiquidSwap(0x744489Ee3d540777A66f2cf297479745e0852f7A);

    /// @notice wrapped HLP depositor
    IWrappedHlpDepositor public depositor = IWrappedHlpDepositor(0x340C9f6159ABc2bdfCC0E2b9Fe91D739006b41c1);

    /// @notice address of the vault deposit token (USDT0)
    address public usdt0 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;

    /// @notice `hyperlend` bytes
    bytes public communityCode = hex"68797065726c656e64";

    constructor() Ownable(msg.sender) {}

    /// @notice function used to swap from token X into USDT0 and then deposit it into wHLP vault
    /// @param tokenIn token user is swapping to wHLP
    /// @param amountIn amount of the input token
    /// @param amountOutMin minimum USDT0 amount after the swap
    /// @param minimumMint minimum wHLP shares received
    /// @param to address that will receive wHLP
    /// @param deadline swap deadline
    /// @param tokens list of tokens in LiquisSwap swap
    /// @param hops list of hops in LiquisSwap swap
    function zapIn(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 minimumMint,
        address to,
        uint256 deadline,
        address[] calldata tokens, 
        ILiquidSwap.Swap[][] calldata hops
    ) external {
        require(block.timestamp < deadline, "wHlpZapper: expired");
        
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(liquidSwapRouter), amountIn);

        liquidSwapRouter.executeMultiHopSwap(tokens, amountIn, amountOutMin, hops);

        uint256 balanceOut = IERC20(usdt0).balanceOf(address(this));
        require(balanceOut >= amountOutMin, "wHlpZapper: minAmountOut > balanceOut");

        IERC20(usdt0).approve(address(depositor), balanceOut);
        depositor.deposit(usdt0, balanceOut, minimumMint, to, communityCode);
    }

    /// @notice used to rescue stuck tokens that were sent to the contract by mistake
    function rescueTokens(address _token, uint256 _amount) external onlyOwner(){
        if (_token == address(0)){
            (bool success, ) = payable(msg.sender).call{value: _amount}("");
            require(success, "transfer failed");
        } else {
            IERC20(_token).safeTransfer(msg.sender, _amount);
        }
    }

    fallback() external payable {}
    receive() external payable {}
}