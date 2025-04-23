// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IPool } from "../interfaces/IPool.sol";
import { IWrappedHype } from "../interfaces/IWrappedHype.sol";
import { ILiquidSwap } from "../interfaces/ILiquidSwap.sol";

/// @title LiquidSwapAdapter
/// @author HyperLend
/// @notice Contract used to swap tokens on LiquidSwap, using uniswap interface
/// @dev Swap relies on pre-setting swap data, so it should be used ONLY with StragegyManager batching!!!
/// @dev it is not great for gas usage, but we are time constrained and gas is cheap...
contract LiquidSwapAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice mapping of tokenIn/tokenOut routes: route = swapRoutes[tokenIn][tokenOut]
    mapping(address => mapping(address => ILiquidSwap.Swap[])) internal swapRoutes;
    mapping(address => mapping(address => uint256)) internal lastUpdateBlock;

    /// @notice liquid swap router
    ILiquidSwap public liquidSwapRouter = ILiquidSwap(0x744489Ee3d540777A66f2cf297479745e0852f7A);

    /// @notice wrapped hype
    IWrappedHype public WHYPE = IWrappedHype(0x5555555555555555555555555555555555555555);

    constructor() {}

    /// @notice used to preset swap route, which will then be used in swapExactTokensForTokensSupportingFeeOnTransferTokens
    /// @dev this is done to avoid changing the existing Looping.sol contract, while adding smarter routing
    function setSwapPath(address tokenIn, address tokenOut, ILiquidSwap.Swap[] calldata paths) external {
        //clear existing path
        delete swapRoutes[tokenIn][tokenOut];

        //allocate and copy manually
        for (uint256 i = 0; i < paths.length; ++i) {
            swapRoutes[tokenIn][tokenOut].push(paths[i]);
        }
        
        lastUpdateBlock[tokenIn][tokenOut] = block.number;
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        address referrer, //unused
        uint deadline
    ) external nonReentrant() {
        require(block.timestamp < deadline, "Swapper: expired");

        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];
        require(lastUpdateBlock[tokenIn][tokenOut] == block.number, "Swapper: path not set in this block");
        
        //use the latest swap path (which must be set in the same transaction)
        ILiquidSwap.Swap[] memory paths = swapRoutes[tokenIn][tokenOut];

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(liquidSwapRouter), amountIn);

        liquidSwapRouter.executeSwap(paths, amountIn, amountOutMin);

        //since liquidswap router could send us some HYPE, we need to wrap it
        if (address(this).balance > 0){
            WHYPE.deposit{value: address(this).balance}();
        }

        uint256 balanceOut = IERC20(tokenOut).balanceOf(tokenOut);
        require(balanceOut >= amountOutMin, "Swapper: minAmountOut > balanceOut");
        IERC20(tokenOut).transfer(to, balanceOut);
    }

    function getSwapRoute(address tokenIn, address tokenOut) external view returns (ILiquidSwap.Swap[] memory) {
        return swapRoutes[tokenIn][tokenOut];
    }
}
