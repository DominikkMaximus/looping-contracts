main()

async function main(){
    const [address1, address2, address3] = await ethers.getSigners();

    const owner = address1;

    const swapper = "0x85aA63EB2ab9BaAA74eAd7e7f82A571d74901853" //hyperswap
    const pool = "0x1e85CCDf0D098a9f55b82F3E35013Eda235C8BD8" //hyperevm testnet deployment

    const Looping = await ethers.getContractFactory("Looping");
    const looping = await Looping.deploy(
        [pool],
        [swapper],
        owner.address
    );
    console.log(`looping deployed to ${looping.target}`)

    const PositionManager = await ethers.getContractFactory("PositionsManager");
    const positionManager = await PositionManager.deploy(owner.address);
    console.log(`positionManager deployed to ${positionManager.target}`)

    const debtAsset = "0xe0bdd7e8b7bf5b15dcDA6103FCbBA82a460ae2C7" //WETH
    const yieldAsset = "0x453b63484b11bbF0b61fC7E854f8DAC7bdE7d458" //mBTC
    const hYieldToken = "0xde72990638db12f8AA4cd9406bA6c648153A5cEA"
    const debtAssetVariableDebtToken = "0xE5C5E18723991AF5D2a640f6C9667D48741429E6" //WETHVariableDebt
    const initialAmount = (0.1 * Math.pow(10, 18)).toString() //ETH
    const flashloanAmount = (0.2 * Math.pow(10, 18)).toString() //ETH
    const minAmountOut = 0;

    const debtInstance = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", debtAsset)

    await debtInstance.connect(owner).approve(positionManager.target, initialAmount)
    console.log(`approved tokens`)

    console.log(await positionManager.increasePosition(
        looping.target,
        pool,
        swapper,
        {
            debtAsset: debtAsset,
            yieldAsset: yieldAsset,
            initialAmount: initialAmount,
            flashloanAmount: flashloanAmount,
            minAmountOut: minAmountOut,
            path: [debtAsset, yieldAsset],
        }
    ))

    // const posManager = await ethers.getContractAt("PositionsManager", "0x8B9Ba07b2EF8e4C7A2a8cE6C166C8289Bce0c6f6")

    console.log(await positionManager.getPositionData(pool, yieldAsset, debtAsset))

    const withdrawAmount = (0.005 * Math.pow(10, 8)).toString()
    console.log(await positionManager.reducePosition(
        looping.target,
        pool,
        swapper,
        {
            debtAsset: debtAsset,
            yieldAsset: yieldAsset,
            initialAmount: 0,
            flashloanAmount: flashloanAmount,
            minAmountOut: minAmountOut,
            path: [yieldAsset, debtAsset],
        },
        withdrawAmount
    ))
}