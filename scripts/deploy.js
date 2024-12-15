main()

async function main(){
    const [owner] = await ethers.getSigners();

    const PositionManager = await ethers.getContractFactory("Looping");
    const positionManager = await PositionManager.deploy();
    console.log(positionManager.target)
}