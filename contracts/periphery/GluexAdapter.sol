// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IWrappedHype} from "../interfaces/IWrappedHype.sol";

/// @title GluexAdapter
/// @author HyperLend
/// @notice Contract used to swap tokens on GlueX, using a uniswap-like interface for integration.
/// @dev Swap relies on pre-setting swap calldata
contract GluexAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice mapping of tokenIn/tokenOut routes to the required GlueX calldata
    mapping(address => mapping(address => bytes)) internal swapRoutes;
    mapping(address => mapping(address => uint256)) internal lastUpdateBlock;

    /// @notice GlueX router address
    address public gluex = 0xe95F6EAeaE1E4d650576Af600b33D9F7e5f9f7fd;

    /// @notice wrapped hype
    IWrappedHype public WHYPE =
        IWrappedHype(0x5555555555555555555555555555555555555555);

    /// @notice used to preset the swap route calldata, which will then be used in the swap function.
    /// @dev This must be called in the same transaction as the swap.
    /// @param tokenIn The input token of the swap.
    /// @param tokenOut The output token of the swap.
    /// @param gluexData The raw calldata to be sent to the GlueX router to perform the swap.
    function setSwapPath(
        address tokenIn,
        address tokenOut,
        bytes calldata gluexData
    ) external {
        swapRoutes[tokenIn][tokenOut] = gluexData;
        lastUpdateBlock[tokenIn][tokenOut] = block.number;
    }

    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible.
    /// @dev The function signature is kept identical to a standard Uniswap V2 router for compatibility.
    /// It relies on `setSwapPath` being called in the same transaction to provide the swap calldata.
    /// @param amountIn The amount of tokens to be swapped.
    /// @param amountOutMin The minimum amount of output tokens that must be received.
    /// @param path An array of token addresses. `path[0]` is the input token, `path[path.length - 1]` is the output token.
    /// @param to The recipient of the output tokens.
    /// @param deadline The deadline for the transaction.
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        address, // referrer; unused in this implementation
        uint deadline
    ) external nonReentrant {
        require(block.timestamp < deadline, "GluexAdapter: expired");

        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        require(
            lastUpdateBlock[tokenIn][tokenOut] == block.number,
            "GluexAdapter: path not set in this block"
        );

        // Use the latest swap path (which must be set in the same transaction)
        bytes memory gluexCallData = swapRoutes[tokenIn][tokenOut];
        require(gluexCallData.length > 0, "GluexAdapter: path data is empty");

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        //approve gluex
        IERC20(tokenIn).safeApprove(address(gluex), amountIn);

        // execute the swap by calling gluex with the preset data
        (bool success, ) = gluex.call(gluexCallData);
        require(success, "GluexAdapter: gluex swap failed");

        // the swap router could send us some HYPE, we need to wrap it
        if (address(this).balance > 0) {
            WHYPE.deposit{value: address(this).balance}();
        }

        uint256 balanceOut = IERC20(tokenOut).balanceOf(address(this));
        require(
            balanceOut >= amountOutMin,
            "GluexAdapter: minAmountOut > balanceOut"
        );
        IERC20(tokenOut).safeTransfer(to, balanceOut);
    }

    /// @notice Gets the stored GlueX calldata for a given token pair.
    function getSwapRoute(
        address tokenIn,
        address tokenOut
    ) external view returns (bytes memory) {
        return swapRoutes[tokenIn][tokenOut];
    }

    fallback() external payable {}
    receive() external payable {}
}
