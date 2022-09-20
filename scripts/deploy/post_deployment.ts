import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { waitFor } from "../txHelper";
import { CONTRACTS, CONFIGURATION } from "../constants";
import { NomicLabsHardhatPluginError } from "hardhat/plugins";
import {
    Treasury__factory,
    Escrow__factory,
} from "../../types";

// TODO: Shouldn't run setup methods if the contracts weren't redeployed.
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    console.log("***** POST DEPLOYMENT TASKS *****");

    console.log("Account balance:", ethers.utils.formatEther((await signer.getBalance()).toString()) + " ETH");

    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const escrowDeployment = await deployments.get(CONTRACTS.escrow);

    const deployerAddress =  signer.getAddress();

    const treasury = await Treasury__factory.connect(treasuryDeployment.address, signer);

}
    
func.tags = ["post-deployment"];
func.dependencies = [CONTRACTS.escrow, CONTRACTS.authority];

export default func;
