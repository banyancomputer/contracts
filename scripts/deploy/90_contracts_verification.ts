import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { waitFor } from "../txHelper";
import { CONTRACTS, CONFIGURATION } from "../constants";
import { NomicLabsHardhatPluginError } from "hardhat/plugins";

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
    
    const network = await ethers.provider.getNetwork();

    const deployerAddress =  signer.getAddress();
    
    if (network.chainId !== CONFIGURATION.hardhatChainId) {

        try {
            console.log("Sleepin' for 30 seconds to wait for the chain to be ready...");
            await delay(30e3); // 30 seconds delay to allow the network to be synced
            await hre.run("verify:verify", {
                address: authorityDeployment.address,
                constructorArguments: [
                    deployer,
                    deployer,
                    deployer,
                    deployer
                ],
            });
            console.log("Verified -- Authority");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- Authority");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }

        try {
            console.log("Sleepin' for 30 seconds to wait for the chain to be ready...");
            await delay(30e3); // 30 seconds delay to allow the network to be synced
            await hre.run("verify:verify", {
                address: treasuryDeployment.address,
                constructorArguments: [authorityDeployment.address],
            });
            console.log("Verified -- treasury Contract");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- treasury Contract");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }

        try {
            console.log("Sleepin' for 30 seconds to wait for the chain to be ready...");
            await delay(30e3); // 30 seconds delay to allow the network to be synced
            await hre.run("verify:verify", {
                address: escrowDeployment.address,
                constructorArguments: [authorityDeployment.address],
            });
            console.log("Verified -- escrow Contract");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- escrow Contract");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }
    }    
};

func.tags = ["verify"];
func.dependencies = [CONTRACTS.escrow, CONTRACTS.authority];

export default func;
