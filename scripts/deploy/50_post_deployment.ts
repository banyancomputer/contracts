import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { waitFor } from "../txHelper";
import { CONTRACTS, CONFIGURATION } from "../constants";
import { NomicLabsHardhatPluginError } from "hardhat/plugins";
import {
    Authority__factory,
    Treasury__factory,
    Escrow__factory,
} from "../../types";

const delay = (ms: number | undefined) => new Promise(resolve => setTimeout(resolve, ms))

// TODO: Shouldn't run setup methods if the contracts weren't redeployed.
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    console.log("Account balance:", ethers.utils.formatEther((await signer.getBalance()).toString()) + " ETH");

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const escrowDeployment = await deployments.get(CONTRACTS.escrow);
    
    const deployerAddress =  signer.getAddress();
    
    const authority = await Authority__factory.connect(authorityDeployment.address, signer);
    console.log("Authority address:", authority.address);
    console.log("Authority Governor Address:", await authority.governor());

    const treasury = await Treasury__factory.connect(treasuryDeployment.address, signer);
    
    await authority.pushVault(treasury.address, true);
    console.log("Authority Vault:", await authority.vault());

}
    
func.tags = ["post-deployment"];
func.dependencies = [CONTRACTS.escrow, CONTRACTS.authority];

export default func;
