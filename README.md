# HyperLend Looping Contracts

- use flashloan to get debtAsset
- swap debtAsset to yieldAsset
- supply yieldAsset
- borrow debtAsset to repay flashloan

---

Users must approve:
- `Looping` contract to spend the initial amount of `debtAsset`
- `Looping` contract to spend `VariableDebtToken` of `debtAsset` (using `approveDelegation`, so contract can borrow on behalf of the user).