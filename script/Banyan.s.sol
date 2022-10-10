// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Escrow } from "../contracts/Escrow.sol";
import { Treasury } from "../contracts/Treasury.sol";

contract BanyanDeployScript is Script {
    function run() external {

        address deployer = vm.envAddress("DEPLOYER");

        vm.startBroadcast(deployer);

        Escrow escrowImplementation = new Escrow();
                
        Treasury treasuryImplementation = new Treasury();

        address escrowAddress = address(escrowImplementation);
        
        address treasuryAddress = address(treasuryImplementation);

        // Suitable for Goerli deployment
        address link = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;

        address oracle = 0xF1a252307Ff9F3fbB9598c9a181385122948b8Ae;

        address admin = 0x2C231Fb9B59b56CdDD413443D90628384b3F1d60;

        escrowImplementation._initialize(link, admin, treasuryAddress, treasuryAddress, oracle);
        
        treasuryImplementation._initialize(escrowAddress, admin);

        vm.stopBroadcast();
    }

}