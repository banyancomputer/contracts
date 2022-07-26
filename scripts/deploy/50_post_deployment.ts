import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { waitFor } from "../txHelper";
import { CONTRACTS, CONFIGURATION } from "../constants";
import { NomicLabsHardhatPluginError } from "hardhat/plugins";
import {
    Authority__factory,
    Treasury__factory,
    Escrow__factory,
    ERC20Mock__factory,
    ERC721Mock__factory,
    ERC1155Mock__factory
} from "../../types";

// TODO: Shouldn't run setup methods if the contracts weren't redeployed.
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    console.log("***** POST DEPLOYMENT TASKS *****");

    console.log("Account balance:", ethers.utils.formatEther((await signer.getBalance()).toString()) + " ETH");

    const erc20MockDeployment = await deployments.get(CONTRACTS.erc20Mock);
    const erc721MockDeployment = await deployments.get(CONTRACTS.erc721Mock);
    const erc1155MockDeployment = await deployments.get(CONTRACTS.erc1155Mock);

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

    const erc721Mock = await ERC721Mock__factory.connect(erc721MockDeployment.address, signer);
    await erc721Mock.mint(deployerAddress);
    console.log("Minted 1 ERC721 token to deployer");

    const erc1155Mock = await ERC1155Mock__factory.connect(erc1155MockDeployment.address, signer);
    await erc1155Mock.mint(deployerAddress, 1, 100, "0x0000000000000000000000000000000000000000");
    console.log("Minted 1 ERC1155 token to deployer without metadata");

}
    
func.tags = ["post-deployment"];
func.dependencies = [CONTRACTS.escrow, CONTRACTS.authority];

export default func;
