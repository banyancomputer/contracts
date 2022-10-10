import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const escrowDeployment = await ethers.getContractFactory("Escrow");
    const treasuryDeployment = await ethers.getContractFactory("Treasury");
    const escrow = await hre.upgrades.deployProxy(escrowDeployment, ["address _link", "address _admin", "address _treasury", "address _oracle"]);
    const treasury = await hre.upgrades.deployProxy(escrowDeployment, ["address escrow", "address _admin"]);

    console.log("escrow proxy deployed at " + escrow.address);
    console.log("treasury proxy deployed at " + treasury.address);
};

export default func;