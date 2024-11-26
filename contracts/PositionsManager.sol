// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IAToken } from "./interfaces/IAToken.sol";
import { IDebtToken } from "./interfaces/IDebtToken.sol";

import { IPool } from "./interfaces/IPool.sol";
import { DataTypes } from "./interfaces/DataTypes.sol";

import { Looping } from "./Looping.sol";

contract PositionsManager is Ownable {
    struct Position {
        bool isOpen;
        address pool;
        address yieldAsset;
        address debtAsset;
        uint256 yieldBalanceScaled;
        uint256 debtBalanceScaled;
        uint256 lastModifiedAt;
    }

    /// @notice array of position Ids
    bytes32[] public positionIds;

    /// @notice mapping of position ID (hashed yieldAsset + debtAsset) to Position struct
    mapping(bytes32 => Position) public positions;

    constructor(address _owner) Ownable(_owner){}

    /// @notice combine the two addresses and hash them
    function getPositionId(address yieldAsset, address debtAsset) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(yieldAsset, debtAsset));
    }

    struct PositionParams {
        address debtAsset;
        address yieldAsset;
        uint256 initialAmount;
        uint256 flashloanAmount;
        uint256 minAmountOut;
        address[] path;
    }

    function increasePosition(
        address _loopingHelper,
        address _pool,
        address _swapper,
        PositionParams memory params
    ) external onlyOwner {
        IERC20(params.debtAsset).transferFrom(msg.sender, address(this), params.initialAmount);
        IERC20(params.debtAsset).approve(_loopingHelper, type(uint256).max);

        DataTypes.ReserveData memory yieldReserveData = IPool(_pool).getReserveData(params.yieldAsset);
        DataTypes.ReserveData memory debtReserveData = IPool(_pool).getReserveData(params.debtAsset);

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

        bytes32 positionId = getPositionId(params.yieldAsset, params.debtAsset);
        positions[positionId] = Position({
            isOpen: true,
            pool: _pool,
            yieldAsset: params.yieldAsset,
            debtAsset: params.debtAsset,
            yieldBalanceScaled: yieldBalanceScaledAfter - yieldBalanceScaledBefore,
            debtBalanceScaled: debtBalanceScaledAfter - debtBalanceScaledBefore,
            lastModifiedAt: block.timestamp
        });
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

        IERC20(params.debtAsset).transferFrom(msg.sender, address(this), params.initialAmount);
        IERC20(params.debtAsset).approve(_loopingHelper, type(uint256).max);
        IERC20(yieldReserveData.aTokenAddress).approve(_loopingHelper, _withdrawAmount);

        uint256 yieldBalanceScaledBefore = IAToken(yieldReserveData.aTokenAddress).scaledBalanceOf(address(this));
        uint256 debtBalanceScaledBefore = IDebtToken(debtReserveData.variableDebtTokenAddress).scaledBalanceOf(address(this));

        Looping(_loopingHelper).closePosition(
            _pool, 
            _swapper,
            params.debtAsset, 
            params.yieldAsset, 
            params.initialAmount, 
            params.flashloanAmount, 
            params.minAmountOut,
            params.path,
            _withdrawAmount
        );

        uint256 yieldBalanceScaledAfter = IAToken(yieldReserveData.aTokenAddress).scaledBalanceOf(address(this));
        uint256 debtBalanceScaledAfter = IDebtToken(debtReserveData.variableDebtTokenAddress).scaledBalanceOf(address(this));

        uint256 yieldBalanceScaled = yieldBalanceScaledAfter - yieldBalanceScaledBefore;
        uint256 debtBalanceScaled = debtBalanceScaledAfter - debtBalanceScaledBefore;

        bytes32 positionId = getPositionId(params.yieldAsset, params.debtAsset);
        positions[positionId] = Position({
            isOpen: yieldBalanceScaled > 0 || debtBalanceScaled > 0,
            pool: _pool,
            yieldAsset: params.yieldAsset,
            debtAsset: params.debtAsset,
            yieldBalanceScaled: yieldBalanceScaled,
            debtBalanceScaled: debtBalanceScaled,
            lastModifiedAt: block.timestamp
        });
    }

    function getPositionData(address _yieldAsset, address _debtAsset) external view returns (
        Position memory pos,
        uint256 yieldBalanceNow,
        uint256 debtBalanceNow
    ) {
        bytes32 positionId = getPositionId(_yieldAsset, _debtAsset);

        pos = positions[positionId];

        DataTypes.ReserveData memory yieldReserveData = IPool(pos.pool).getReserveData(pos.yieldAsset);
        DataTypes.ReserveData memory debtReserveData = IPool(pos.pool).getReserveData(pos.debtAsset);

        yieldBalanceNow = (pos.yieldBalanceScaled * yieldReserveData.liquidityIndex) * 1e18 / 1e27;
        debtBalanceNow = (pos.debtBalanceScaled * debtReserveData.variableBorrowIndex) * 1e18 / 1e27;
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
}