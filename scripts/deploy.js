main()

async function main(){
    const [owner] = await ethers.getSigners();

    // const PositionManager = await ethers.getContractFactory("Looping");
    // const positionManager = await PositionManager.deploy(
    //     ['0x00A89d7a5A02160f20150EbEA7a2b5E4879A1A8b'], ['0xb4a9C4e6Ea8E2191d2FA5B380452a634Fb21240A'], '0x1B7a7d51eE86e1d9776986AEFD2675312CF0C9Da'
    // );
    // console.log(positionManager.target)

    const Swapper = await ethers.getContractFactory("LiquidSwapAdapter");
    const swapper = await Swapper.deploy();
    console.log(swapper.target)
}