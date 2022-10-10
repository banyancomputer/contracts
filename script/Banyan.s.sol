// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { Escrow } from "../contracts/Escrow.sol";
import { Treasury } from "../contracts/Treasury.sol";

contract BanyanDeployScript is Script {

    // Suitable for Goerli deployment
    address link = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;

    address oracle = 0xF1a252307Ff9F3fbB9598c9a181385122948b8Ae;

    address admin = 0x2C231Fb9B59b56CdDD413443D90628384b3F1d60;

    ProxyAdmin proxyAdmin;
    TransparentUpgradeableProxy escrowProxy;
    TransparentUpgradeableProxy treasuryProxy;

    function initialDeploy() external {

        address deployer = vm.envAddress("DEPLOYER");

        vm.startBroadcast(deployer);

        Escrow escrowImplementation = new Escrow();
                
        Treasury treasuryImplementation = new Treasury();

        proxyAdmin = new ProxyAdmin();

        escrowProxy = new TransparentUpgradeableProxy(address(escrowImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address,address,address)", link, admin, address(treasuryImplementation), oracle));
        treasuryProxy = new TransparentUpgradeableProxy(address(treasuryImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address)", address(escrowImplementation), admin));

        address escrowAddress = address(escrowImplementation);
        
        address treasuryAddress = address(treasuryImplementation);

        escrowImplementation._initialize(link, admin, treasuryAddress, oracle);
        
        treasuryImplementation._initialize(escrowAddress, admin);

        vm.stopBroadcast();
    }

    function upgrade() external {
        Escrow newEscrowImplementation = new Escrow();
        Treasury newTreasuryImplementation = new Treasury();

        newEscrowImplementation._initialize(link, admin, address(newTreasuryImplementation), oracle);
        newTreasuryImplementation._initialize(address(newEscrowImplementation), admin);

        proxyAdmin.upgrade(escrowProxy, address(newEscrowImplementation));
        proxyAdmin.upgrade(treasuryProxy, address(newTreasuryImplementation));
    }

}