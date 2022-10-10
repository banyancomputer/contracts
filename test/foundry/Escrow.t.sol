// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "../../contracts/Escrow.sol";
import "../../contracts/Treasury.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {Utilities} from "./utils/Utilities.sol";
import {BaseTest} from "./BaseTest.sol";
import {stdError} from "forge-std/Test.sol";

contract EscrowTest is BaseTest {

    // using Chainlink for Chainlink.Request;

    address payable public admin;
    address payable public user;
    address payable public executor;
    address payable public creator;
    address payable public replacementAdmin;

    //TODO: mocks
    address link = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address oracle = 0xF1a252307Ff9F3fbB9598c9a181385122948b8Ae;

    Escrow escrowImplementation;
    Treasury treasuryImplementation;
    TransparentUpgradeableProxy escrowProxy;
    TransparentUpgradeableProxy treasuryProxy;
    ProxyAdmin proxyAdmin;

    constructor() {
        preSetup(5);
    }

    function setUp() public override {
        super.setUp();

        //Create attacker address and two mock addresses for pools.
        admin = users[0];
        user = users[1];
        executor = users[2];
        creator = users[3];
        replacementAdmin = users[4];
        //Instantiate contracts

    }

    // Contracts should be upgradeable
    function test_upgradeLogic() public {

        escrowImplementation = new Escrow();
        treasuryImplementation = new Treasury();

        proxyAdmin = new ProxyAdmin();

        escrowProxy = new TransparentUpgradeableProxy(address(escrowImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address,address,address)", link, admin, address(treasuryImplementation), oracle));
        treasuryProxy = new TransparentUpgradeableProxy(address(treasuryImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address)", address(escrowImplementation), admin));

        assertEq(proxyAdmin.getProxyImplementation(escrowProxy), address(escrowImplementation));
        assertEq(proxyAdmin.getProxyImplementation(treasuryProxy), address(treasuryImplementation));

        Escrow newEscrowImplementation = new Escrow();
        Treasury newTreasuryImplementation = new Treasury();

        newEscrowImplementation._initialize(link, admin, address(newTreasuryImplementation), oracle);
        newTreasuryImplementation._initialize(address(newEscrowImplementation), admin);

        proxyAdmin.upgrade(escrowProxy, address(newEscrowImplementation));
        proxyAdmin.upgrade(treasuryProxy, address(newTreasuryImplementation));

        assertEq(proxyAdmin.getProxyImplementation(escrowProxy), address(newEscrowImplementation));
        assertEq(proxyAdmin.getProxyImplementation(treasuryProxy), address(newTreasuryImplementation));
    }

    // Deals should be initializable with correct metadata
    function test_dealsInitializable() public {

    }

    // Offers should be joinable by provider (and only designated providers)
    function test_joinOffer() public {

    }

    // Offers should be rescindable (not after both parties accept)
    function test_rescindOffer() public {

    }

    // Deals in progress should be cancellable by consensus of both parties
    function test_cancelOffer() public {

    }

    // Funds will not be held hostage upon completion of deal
    function test_fundHostage() public {

    }

    // Proofs can be saved (at correct block times)
    function test_saveProof() public {

    }

    // The various verify statements revert or pass as expected
    function test_verify() public {

    }

    // Deal is completable and finalizable
    function test_finalization() public {

    }

    // Admin, Treasury can be set; LINK withdrawable
    function test_admin() public {

    }

    // Getters should always return the correct values
    function test_getters() public {

    }
}