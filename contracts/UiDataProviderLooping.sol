// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IUiPoolDataProviderV3 } from "./interfaces/IUiPoolDataProviderV3.sol";
import { IPoolAddressesProvider } from "./interfaces/IPoolAddressesProvider.sol"; 

/// @notice contract used by the UI to display position data in looping-vault-like format
contract UiDataProviderLooping {
    function getUserReservesData(
        address uiPoolDataProvider,
        address poolAddressesProvider,
        address user
    ) external view returns (IUiPoolDataProviderV3.UserReserveData[] memory, uint8) {
        return IUiPoolDataProviderV3(uiPoolDataProvider).getUserReservesData(IPoolAddressesProvider(poolAddressesProvider), user);
    }

    struct UserReserveData {
        address underlyingAsset;
        uint256 scaledATokenBalance;
        bool usageAsCollateralEnabledOnUser;
        uint256 stableBorrowRate;
        uint256 scaledVariableDebt;
        uint256 principalStableDebt;
        uint256 stableBorrowLastUpdateTimestamp;
    }

    function getPosition(address user, address debtAsset, address yieldAsset) external {
        address uiPoolDataProvider = 0x3B3E98B61AFB357b1AA7Ff8BD83BE5516906c659;
        address poolAddressesProvider = 0xa1d0ca19d6877cE4Bf51496305393aa28607012d;

        (IUiPoolDataProviderV3.UserReserveData[] memory reserves, ) = IUiPoolDataProviderV3(uiPoolDataProvider).getUserReservesData(IPoolAddressesProvider(poolAddressesProvider), user);
        
        for (uint256 i = 0; i < reserves.length; i++){
            if (reserves[i].underlyingAsset == debtAsset){

            }

            if (reserves[i].underlyingAsset == yieldAsset){

            }
        }
    }
}