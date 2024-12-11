// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IAToken } from "../interfaces/IAToken.sol";
import { IDebtToken } from "../interfaces/IDebtToken.sol";

import { IPool } from "../interfaces/IPool.sol";
import { DataTypes } from "../interfaces/DataTypes.sol";

import { Looping } from "../Looping.sol";

/// @title PositionsManager
/// @author HyperLend
/// @notice Contract used to manage leveraged positions
contract PositionsManagerDeprecated is Ownable {
    /// @param _owner initial owner of the PositionManager
    constructor(address _owner) Ownable(_owner){}

    /// @notice information about certain position
    struct Position {
        bool isOpen;                  // signals if the position is currently active (has collateral or debt)
        address pool;                 // address of the pool used to borrow/supply
        address yieldAsset;           // asset we want to maximize the supplying of
        address debtAsset;            // asset we are borrowing
        uint256 yieldBalanceScaled;   // scaled balance of supplied yieldAsset
        uint256 debtBalanceScaled;    // scaled debt amount
        uint256 lastModifiedAt;       // timstamp of the last position modification
        uint256 assetsUsed;           // total amount of debtAsset used to open the leveraged position
    }

    /// @notice position parameters data, used to avoid stack-too-deep errors
    struct PositionParams {
        address debtAsset;         // asset we are borrowing
        address yieldAsset;        // asset we want to maximize the supplying of
        uint256 initialAmount;     // initial amount of debtAsset we are providing
        uint256 flashloanAmount;   // amount of the debtAsset we want to flashloan and then to swap to yieldAsset
        uint256 minAmountOut;      // minimum amount of yieldAsset we want to receive when swapping flashloanAmount of debtAsset to yieldAsset
        address[] path;            // path of tokens in liquidiaty pools we want to use when swapping debtAsset to yieldAsset
    }

    /// @notice array of position Ids
    bytes32[] public positionIds;

    /// @notice mapping of position ID (hashed yieldAsset + debtAsset) to Position struct
    mapping(bytes32 => Position) public positions;

    /// @notice combine the pool, yieldAsset and debtAsset addresses and hash them
    function getPositionId(address pool, address yieldAsset, address debtAsset) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(pool, yieldAsset, debtAsset));
    }

    /// @notice used to increase leveraged position
    function increasePosition(
        address _loopingHelper,
        address _pool,
        address _swapper,
        PositionParams memory params
    ) external onlyOwner {
        IERC20(params.debtAsset).transferFrom(msg.sender, address(this), params.initialAmount);
        IERC20(params.debtAsset).approve(_loopingHelper, params.initialAmount);

        DataTypes.ReserveData memory yieldReserveData = IPool(_pool).getReserveData(params.yieldAsset);
        DataTypes.ReserveData memory debtReserveData = IPool(_pool).getReserveData(params.debtAsset);

        //approve debt tokens, so loopingHelper can borrow on our behalf
        IDebtToken(debtReserveData.variableDebtTokenAddress).approveDelegation(_loopingHelper, type(uint256).max);

        uint256 yieldBalanceScaledBefore = IAToken(yieldReserveData.aTokenAddress).scaledBalanceOf(address(this));
        uint256 debtBalanceScaledBefore = IDebtToken(debtReserveData.variableDebtTokenAddress).scaledBalanceOf(address(this));

        Looping(_loopingHelper).openPosition(
            _pool,
            _swapper,
            params.debtAsset,
            params.yieldAsset,
            params.initialAmount,
            params.flashloanAmount,
            params.minAmountOut,
            params.path
        );

        uint256 yieldBalanceScaledAfter = IAToken(yieldReserveData.aTokenAddress).scaledBalanceOf(address(this));
        uint256 debtBalanceScaledAfter = IDebtToken(debtReserveData.variableDebtTokenAddress).scaledBalanceOf(address(this));

        bytes32 positionId = getPositionId(_pool, params.yieldAsset, params.debtAsset);
        positions[positionId] = Position({
            isOpen: true,
            pool: _pool,
            yieldAsset: params.yieldAsset,
            debtAsset: params.debtAsset,
            yieldBalanceScaled: positions[positionId].yieldBalanceScaled + (yieldBalanceScaledAfter - yieldBalanceScaledBefore),
            debtBalanceScaled: positions[positionId].debtBalanceScaled + (debtBalanceScaledAfter - debtBalanceScaledBefore),
            lastModifiedAt: block.timestamp,
            assetsUsed: positions[positionId].assetsUsed + params.initialAmount
        });

        _refund(params.debtAsset, params.yieldAsset, msg.sender);
    }


    function reducePosition(
        address _loopingHelper,
        address _pool, 
        address _swapper,
        PositionParams memory params,
        uint256 _withdrawAmount
    ) external onlyOwner() {
        DataTypes.ReserveData memory yieldReserveData = IPool(_pool).getReserveData(params.yieldAsset);
        DataTypes.ReserveData memory debtReserveData = IPool(_pool).getReserveData(params.debtAsset);

        //approve hToken, so loopingHelper can withdraw on our behalf
        IERC20(yieldReserveData.aTokenAddress).approve(_loopingHelper, _withdrawAmount);

        uint256 yieldBalanceScaledBefore = IAToken(yieldReserveData.aTokenAddress).scaledBalanceOf(address(this));
        uint256 debtBalanceScaledBefore = IDebtToken(debtReserveData.variableDebtTokenAddress).scaledBalanceOf(address(this));

        Looping(_loopingHelper).closePosition(
            _pool, 
            _swapper,
            params.debtAsset, 
            params.yieldAsset, 
            params.flashloanAmount, 
            params.minAmountOut,
            params.path,
            _withdrawAmount
        );

        uint256 yieldBalanceScaledAfter = IAToken(yieldReserveData.aTokenAddress).scaledBalanceOf(address(this));
        uint256 debtBalanceScaledAfter = IDebtToken(debtReserveData.variableDebtTokenAddress).scaledBalanceOf(address(this));

        uint256 debtAssetReceived = IERC20(params.debtAsset).balanceOf(address(this));

        bytes32 positionId = getPositionId(_pool, params.yieldAsset, params.debtAsset);
        positions[positionId] = Position({
            isOpen: yieldBalanceScaledAfter > 0 || debtBalanceScaledAfter > 0,
            pool: _pool,
            yieldAsset: params.yieldAsset,
            debtAsset: params.debtAsset,
            yieldBalanceScaled: positions[positionId].yieldBalanceScaled - (yieldBalanceScaledBefore - yieldBalanceScaledAfter),
            debtBalanceScaled: positions[positionId].debtBalanceScaled - (debtBalanceScaledBefore - debtBalanceScaledAfter),
            lastModifiedAt: block.timestamp,
            assetsUsed: positions[positionId].assetsUsed > debtAssetReceived ? positions[positionId].assetsUsed - debtAssetReceived : 0
        });

        _refund(params.debtAsset, params.yieldAsset, msg.sender);
    }

    function getPositionData(address _pool, address _yieldAsset, address _debtAsset) external view returns (
        Position memory pos,
        uint256 yieldBalanceNow,
        uint256 debtBalanceNow
    ) {
        bytes32 positionId = getPositionId(_pool, _yieldAsset, _debtAsset);

        pos = positions[positionId];

        DataTypes.ReserveData memory yieldReserveData = IPool(pos.pool).getReserveData(pos.yieldAsset);
        DataTypes.ReserveData memory debtReserveData = IPool(pos.pool).getReserveData(pos.debtAsset);

        yieldBalanceNow = (pos.yieldBalanceScaled * yieldReserveData.liquidityIndex) / 1e27;
        debtBalanceNow = (pos.debtBalanceScaled * debtReserveData.variableBorrowIndex) / 1e27;
    }

    function multicall(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory data
    ) external onlyOwner() {
        for (uint256 i = 0; i < targets.length; i++){
            customCall(targets[i], values[i], signatures[i], data[i]);
        }
    }

    /// @notice used to make custom calls to rescue any possibly stuck assets
    function customCall(address target, uint256 value, string memory signature, bytes memory data) public onlyOwner() {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, ) = target.call{value: value}(callData);
        require(success, 'customCall failed');
    }

    /// @notice used to refund any tokens that would remain in the contract after the flashloan repayment
    /// @param debtAsset address of the token we want to borrow
    /// @param yieldAsset address of the token we want to supply
    /// @param user address to send the tokens to
    function _refund(address debtAsset, address yieldAsset, address user) internal {
        uint256 debtAssetBalance = IERC20(debtAsset).balanceOf(address(this));
        uint256 yieldAssetBalance = IERC20(yieldAsset).balanceOf(address(this));

        if (debtAssetBalance > 0){
            IERC20(debtAsset).transfer(user, debtAssetBalance);
        }
        if (yieldAssetBalance > 0){
            IERC20(yieldAsset).transfer(user, yieldAssetBalance);
        }
    }
}