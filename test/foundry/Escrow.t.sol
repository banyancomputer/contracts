// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "../../contracts/Escrow.sol";
import "../../contracts/Treasury.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "./utils/mocks/USDC.sol";

import {Utilities} from "./utils/Utilities.sol";
import {BaseTest} from "./BaseTest.sol";
import {stdError} from "forge-std/Test.sol";

contract EscrowTest is BaseTest {

    // using Chainlink for Chainlink.Request;
    event Response(bool success, bytes data);

    address payable public admin;
    address payable public user;
    address payable public executor;
    address payable public creator;
    address payable public replacementAdmin;
    address payable public replacementTreasury;

    //TODO: mocks
    address link = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address oracle = 0xF1a252307Ff9F3fbB9598c9a181385122948b8Ae;

    Escrow escrowImplementation;
    Treasury treasuryImplementation;
    TransparentUpgradeableProxy escrowProxy;
    TransparentUpgradeableProxy treasuryProxy;
    ProxyAdmin proxyAdmin;
    MockERC20 usdc;
    MockERC20 weth;

    constructor() {
        preSetup(6);
    }

    function setUp() public override {
        super.setUp();

        //Create attacker address and two mock addresses for pools.
        admin = users[0];
        user = users[1];
        executor = users[2];
        creator = users[3];
        replacementAdmin = users[4];
        replacementTreasury = users[5];

        usdc = new MockERC20("USDC", "USDC");

        usdc.mint(admin, 1e20);
        usdc.mint(user, 1e20);
        usdc.mint(executor, 1e20);

        weth = new MockERC20("WETH", "WETH");

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

        escrowImplementation = new Escrow();
        treasuryImplementation = new Treasury();

        proxyAdmin = new ProxyAdmin();

        escrowProxy = new TransparentUpgradeableProxy(address(escrowImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address,address,address)", link, admin, address(treasuryImplementation), oracle));
        treasuryProxy = new TransparentUpgradeableProxy(address(treasuryImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address)", address(escrowImplementation), admin));

        vm.startPrank(user);

        // Does not initialize deal with 0 inputs
        vm.expectRevert();
        (bool s, bytes memory d) = address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("startOffer(address,uint256,uint256,uint256,uint256,address,uint256,string,string)", executor, 0, 0, 0, 0, address(usdc), 0, "", "")
        );
        assertEq(s, false);
        emit Response(s, d);

        // Does not initialize deal when user does not have enough balance
        vm.expectRevert();
        (bool success, bytes memory data) = address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("startOffer(address,uint256,uint256,uint256,uint256,address,uint256,string,string)", executor, 1, 1, 1, 1, address(weth), 1, "", "")
        );
        assertEq(success, false);
        emit Response(success, data);

        address(usdc).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("approve(address,uint256)", address(treasuryImplementation), 2)
        );

        (bool result, bytes memory txdata) = address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("startOffer(address,uint256,uint256,uint256,uint256,address,uint256,string,string)", executor, 1, 1, 1, 1, address(usdc), 1, "", "")
        );
        assertEq(result, true);
        emit Response(success, txdata);
        
        vm.stopPrank();
    }

    // Offers should be joinable by provider (and only designated providers)
    function test_joinOffer() public {
        escrowImplementation = new Escrow();
        treasuryImplementation = new Treasury();

        proxyAdmin = new ProxyAdmin();

        escrowProxy = new TransparentUpgradeableProxy(address(escrowImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address,address,address)", link, admin, address(treasuryImplementation), oracle));
        treasuryProxy = new TransparentUpgradeableProxy(address(treasuryImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address)", address(escrowImplementation), admin));

        vm.startPrank(user);

        address(usdc).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("approve(address,uint256)", address(treasuryImplementation), 2)
        );

        (bool startsuccess, bytes memory startdata) = address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("startOffer(address,uint256,uint256,uint256,uint256,address,uint256,string,string)", executor, 1, 1, 1, 1, address(usdc), 1, "", "")
        );
        assertEq(startsuccess, true);
        emit Response(startsuccess, startdata);

        vm.expectEmit(true, true, false, false);
        emit Response(true, abi.encode(1));
        (bool returnvalueSuccess, bytes memory returnvalue) = address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("getCollateral(uint256)", 1)
        );
        emit Response(returnvalueSuccess, returnvalue);
        
        vm.stopPrank();

        vm.prank(creator);
        // JoinOffer should fail if not enough funds
        vm.expectRevert();
        address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("joinOffer(uint256)", 1)
        );

        usdc.mint(creator, 1e20);

        vm.prank(creator);
        address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("joinOffer(uint256)", 1)
        );

        vm.startPrank(executor);

        (bool allowanceSuccess, ) = address(usdc).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("approve(address,uint256)", address(treasuryImplementation), abi.decode(returnvalue, (uint)))
        );
        assertEq(allowanceSuccess, true);

        // JoinOffer should fail if provider has not enough funds for collateral locking
        (bool joinsuccess, bytes memory joindata) = address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("joinOffer(uint256)", 1)
        );
        assertEq(joinsuccess, true);

        emit Response(joinsuccess, joindata);
    }

    // Offers should be rescindable (not after both parties accept)
    function test_rescindOffer() public {
        escrowImplementation = new Escrow();
        treasuryImplementation = new Treasury();

        proxyAdmin = new ProxyAdmin();

        escrowProxy = new TransparentUpgradeableProxy(address(escrowImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address,address,address)", link, admin, address(treasuryImplementation), oracle));
        treasuryProxy = new TransparentUpgradeableProxy(address(treasuryImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address)", address(escrowImplementation), admin));

        assertEq(proxyAdmin.getProxyImplementation(escrowProxy), address(escrowImplementation));
        assertEq(proxyAdmin.getProxyImplementation(treasuryProxy), address(treasuryImplementation));

        vm.startPrank(user);

        // JoinOffer should fail if deal starter has not enough funds
        (bool startsuccess, bytes memory startdata) = address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("startOffer(address,uint256,uint256,uint256,uint256,address,uint256,string,string)", executor, 1, 1, 1, 1, 0x7af963cF6D228E564e2A0aA0DdBF06210B38615D, 1, "", "")
        );
        emit Response(startsuccess, startdata);

        // Rescindoffer should succeed only before acceptance
        (bool success, bytes memory data) = address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("rescindOffer(uint256)", 1)
        );
        emit Response(success, data);

        // JoinOffer should fail if deal starter has not enough funds
        address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("startOffer(address,uint256,uint256,uint256,uint256,address,uint256,string,string)", executor, 1, 1, 1, 1, 0x7af963cF6D228E564e2A0aA0DdBF06210B38615D, 1, "", "")
        );

        vm.stopPrank();

        vm.prank(executor);

        // JoinOffer should fail if executor has not enough funds
        (bool joinsuccess, bytes memory joindata) = address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("joinOffer(uint256)", 1)
        );

        emit Response(joinsuccess, joindata);

        vm.prank(user);

        vm.expectRevert();
        (bool shouldfail, bytes memory faildata) = address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("rescindOffer(uint256)", 1)
        );
        emit Response(shouldfail, faildata);

    }

    // Deals in progress should be cancellable by consensus of both parties
    function test_cancelOffer() public {
        escrowImplementation = new Escrow();
        treasuryImplementation = new Treasury();

        proxyAdmin = new ProxyAdmin();

        escrowProxy = new TransparentUpgradeableProxy(address(escrowImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address,address,address)", link, admin, address(treasuryImplementation), oracle));
        treasuryProxy = new TransparentUpgradeableProxy(address(treasuryImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address)", address(escrowImplementation), admin));

        assertEq(proxyAdmin.getProxyImplementation(escrowProxy), address(escrowImplementation));
        assertEq(proxyAdmin.getProxyImplementation(treasuryProxy), address(treasuryImplementation));

        vm.prank(user);

        address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("startOffer(address,uint256,uint256,uint256,uint256,address,uint256,string,string)", executor, 1, 1, 1, 1, 0x7af963cF6D228E564e2A0aA0DdBF06210B38615D, 1, "", "")
        );

        vm.prank(executor);

        address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("joinOffer(uint256)", 1)
        );

        vm.prank(user);

        address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("cancelOffer(uint256)", 1)
        );

        vm.prank(executor);
        address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("cancelOffer(uint256)", 1)
        );
    }

    // TODO: Proofs can be saved (at correct block times)
    function test_saveProof() public {
        escrowImplementation = new Escrow();
        treasuryImplementation = new Treasury();

        proxyAdmin = new ProxyAdmin();

        escrowProxy = new TransparentUpgradeableProxy(address(escrowImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address,address,address)", link, admin, address(treasuryImplementation), oracle));
        treasuryProxy = new TransparentUpgradeableProxy(address(treasuryImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address)", address(escrowImplementation), admin));

        vm.prank(user);

        address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("startOffer(address,uint256,uint256,uint256,uint256,address,uint256,string,string)", executor, 1, 1, 1, 1, 0x7af963cF6D228E564e2A0aA0DdBF06210B38615D, 1, "", "")
        );

        vm.prank(executor);

        address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("joinOffer(uint256)", 1)
        );

        vm.prank(executor);
        address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("saveProof(bytes,uint256,uint256)", 1, 1, 1)
        );

        vm.prank(executor);
        vm.expectRevert();
        address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("fulfill(bytes32,uint256,uint256,uint256,uint16,string)", 1, 1, 1, 1, 1, "")
        );
    }

    // TODO: Deal is completable and finalizable
    function test_finalization() public {
        escrowImplementation = new Escrow();
        treasuryImplementation = new Treasury();

        proxyAdmin = new ProxyAdmin();

        escrowProxy = new TransparentUpgradeableProxy(address(escrowImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address,address,address)", link, admin, address(treasuryImplementation), oracle));
        treasuryProxy = new TransparentUpgradeableProxy(address(treasuryImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address)", address(escrowImplementation), admin));

        vm.prank(user);

        address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("startOffer(address,uint256,uint256,uint256,uint256,address,uint256,string,string)", executor, 1, 1, 1, 1, 0x7af963cF6D228E564e2A0aA0DdBF06210B38615D, 1, "", "")
        );

        vm.prank(executor);

        address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("joinOffer(uint256)", 1)
        );

        vm.prank(user);
        address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("complete(uint256,uint256)", 1, 8000)
        );
    }

    // Admin, Treasury can be set; LINK withdrawable
    function test_admin() public {
        escrowImplementation = new Escrow();
        treasuryImplementation = new Treasury();

        proxyAdmin = new ProxyAdmin();

        escrowProxy = new TransparentUpgradeableProxy(address(escrowImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address,address,address)", link, admin, address(treasuryImplementation), oracle));
        treasuryProxy = new TransparentUpgradeableProxy(address(treasuryImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address)", address(escrowImplementation), admin));

        assertEq(proxyAdmin.getProxyImplementation(escrowProxy), address(escrowImplementation));
        assertEq(proxyAdmin.getProxyImplementation(treasuryProxy), address(treasuryImplementation));

        vm.prank(admin);

        (bool success, bytes memory data) = address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("setAdmin(address)", replacementAdmin)
        );
        emit Response(success, data);

        vm.prank(replacementAdmin);
        (bool s, bytes memory d) = address(escrowProxy).call{value: 0, gas: 200000000}(
            abi.encodeWithSignature("setTreasury(address)", replacementTreasury)
        );
        emit Response(s, d);
    }

    // Getters should always return the correct values
    function test_getters() public {
        escrowImplementation = new Escrow();
        treasuryImplementation = new Treasury();

        proxyAdmin = new ProxyAdmin();

        escrowProxy = new TransparentUpgradeableProxy(address(escrowImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address,address,address)", link, admin, address(treasuryImplementation), oracle));
        treasuryProxy = new TransparentUpgradeableProxy(address(treasuryImplementation), address(proxyAdmin), abi.encodeWithSignature("_initialize(address,address)", address(escrowImplementation), admin));

        assertEq(proxyAdmin.getProxyImplementation(escrowProxy), address(escrowImplementation));
        assertEq(proxyAdmin.getProxyImplementation(treasuryProxy), address(treasuryImplementation));

        vm.prank(user);
        address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("startOffer(address,uint256,uint256,uint256,uint256,address,uint256,string,string)", executor, 1, 1, 1, 1, 0x7af963cF6D228E564e2A0aA0DdBF06210B38615D, 1, "", "")
        );
        (bool s, bytes memory d) = address(escrowProxy).call{value: 1, gas: 200000000}(
            abi.encodeWithSignature("getOffer(uint256)", 1)
        );
        emit Response(s, d);
    }
}