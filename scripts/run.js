main()

async function main(){
    const [owner] = await ethers.getSigners();

    const Looping = await ethers.getContractFactory("Looping");
    const looping = await Looping.deploy();
    console.log(`looping deployed to ${looping.target}`)

    const swapper = "0x85aA63EB2ab9BaAA74eAd7e7f82A571d74901853" //hyperswap
    await looping.toggleSwapper(swapper);

    const pool = "0x1e85CCDf0D098a9f55b82F3E35013Eda235C8BD8" //hyperevm testnet deployment
    await looping.togglePool(pool);

    const debtAsset = "0xe0bdd7e8b7bf5b15dcDA6103FCbBA82a460ae2C7" //WETH
    const yieldAsset = "0x453b63484b11bbF0b61fC7E854f8DAC7bdE7d458" //mBTC
    const debtAssetVariableDebtToken = "0xE5C5E18723991AF5D2a640f6C9667D48741429E6" //WETHVariableDebt
    const initialAmount = (0.1 * Math.pow(10, 18)).toString() //0.1 ETH`
    const minAmountOut = 0;
    const flashloanAmount = (0.3 * Math.pow(10, 18)).toString() //0.3 ETH

    const debtInstance = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", debtAsset)
    const yieldInstance = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", yieldAsset) 
    const debtVariableDebtInstance = await ethers.getContractAt("IDebtToken", debtAssetVariableDebtToken)
    await debtVariableDebtInstance.connect(owner).approveDelegation(looping.target, "9999999999999999999999999999999999999999999999999999999999999999999999999999")

    await debtInstance.approve(looping.target, initialAmount)

    //simulate swap
    await yieldInstance.approve(looping.target, 1 * Math.pow(10, 8))

    console.log(await looping.connect(owner).leverage(
        pool,
        swapper,
        debtAsset,
        yieldAsset,
        initialAmount,
        flashloanAmount,
        minAmountOut,
        [debtAsset, yieldAsset]
    ))
    console.log(`leveraged position opened`)
}