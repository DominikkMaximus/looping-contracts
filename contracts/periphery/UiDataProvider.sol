// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IPool } from "../interfaces/IPool.sol";

import { StrategyManagerFactory } from "../StrategyManagerFactory.sol";
import { StrategyManager } from "../StrategyManager.sol";

contract UiDataProvider {
    struct UserStrategy {
        address pool;
        address yieldAsset;
        address debtAsset;
        string yieldSymbol;
        string debtSymbol;
    }

    struct UserStrategies {
        address user;
        UserStrategy[] strategyManagers;
    }

    struct StrategyDetailed {
        address manager;
        address pool;
        address yieldAsset;
        address debtAsset;
        uint256 healthFactor;
        uint256 positionValueUsd;
        uint256 debtValueUsd;
        uint256 yieldValueUsd;
        uint256 leverage;
        uint256 netApy;
    }

    function getUserStrategies(address _factory, address _user) external view returns (UserStrategies memory) {
        StrategyManagerFactory factory = StrategyManagerFactory(_factory);
        
        address[] memory managers = factory.getUserStrategyManagers(_user);
        UserStrategy[] memory userStrategyArray = new UserStrategy[](managers.length);

        for (uint256 i = 0; i < managers.length; i++){
            StrategyManager manager = StrategyManager(managers[i]);

            userStrategyArray[i] = UserStrategy({
                pool: manager.pool(),
                yieldAsset: manager.yieldAsset(),
                debtAsset: manager.debtAsset(),
                yieldSymbol: IERC20Metadata(manager.yieldAsset()).symbol(),
                debtSymbol: IERC20Metadata(manager.debtAsset()).symbol()
            });
        }

        UserStrategies memory userStrategies = UserStrategies({
            user: _user,
            strategyManagers: userStrategyArray
        });

        return userStrategies;
    }

    function getStrategy(address _manager) external view returns (StrategyDetailed memory) {
        StrategyManager manager = StrategyManager(_manager);
        IPool pool = IPool(manager.pool());

        IERC20Metadata yieldAsset = IERC20Metadata(manager.yieldAsset());
        IERC20Metadata debtAsset = IERC20Metadata(manager.debtAsset());

        DataTypes.ReserveData memory yieldReserve = pool.getReserveData(yieldAsset);
        DataTypes.ReserveData memory debtReserve = pool.getReserveData(debtAsset);

        IERC20Metadata aYieldToken = IERC20Metadata(yieldReserve.aTokenAddress);
        IERC20Metadata variableDebtToken = IERC20Metadata(debtReserve.variableDebtTokenAddress);

        uint256 debt = aYieldToken.balanceOf(manager);
        uint256 supply = variableDebtToken.balanceOf(manager);

        return StrategyDetailed({
            manager: _manager,
            pool: manager.pool(),
            yieldAsset: address(yieldAsset),
            debtAsset: address(debtAsset),
            healthFactor: 0,
            positionValueUsd: 0,
            debtValueUsd: 0,
            yieldValueUsd: 0,
            leverage: 0,
            netApy: 0,
        });
    }
}