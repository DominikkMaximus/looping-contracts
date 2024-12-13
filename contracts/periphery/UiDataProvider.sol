// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { StrategyManagerFactory } from "../StrategyManagerFactory.sol";
import { StrategyManager } from "../StrategyManager.sol";

contract UiDataProvider {
    struct UserStrategy {
        address pool;
        address yieldAsset;
        address debtAsset;
    }

    struct UserStrategies {
        address user;
        UserStrategy[] strategyManagers;
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
                debtAsset: manager.debtAsset()
            });
        }

        UserStrategies memory userStrategies = UserStrategies({
            user: _user,
            strategyManagers: userStrategyArray
        });

        return userStrategies;
    }
}