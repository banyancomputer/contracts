// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "../../contracts/Escrow.sol";
import "../../contracts/Treasury.sol";

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

    //Mocks
    address oracle;
    address link;

    Escrow escrow;
    Treasury treasury;

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
        vm.startBroadcast();
        escrow = new Escrow();
        treasury = new Treasury();
        escrow._initialize(link, admin, address(treasury), oracle);
        Escrow newEscrow = new Escrow();
        escrow.upgradeTo(address(newEscrow));

    }

    // Deals should be initializable with correct metadata
    function test_dealsInitializable() {

    }

    // Offers should be joinable by provider (and only designated providers)
    function test_joinOffer() {

    }

    // Offers should be rescindable (not after both parties accept)
    function test_rescindOffer() {

    }

    // Deals in progress should be cancellable by consensus of both parties
    function test_cancelOffer() {

    }

    // Funds will not be held hostage upon completion of deal
    function test_fundHostage() {

    }

    // Proofs can be saved (at correct block times)
    function test_saveProof() {

    }

    // The various verify statements revert or pass as expected
    function test_verify() {

    }

    // Deal is completable and finalizable
    function test_finalization() {

    }

    // Admin, Treasury can be set; LINK withdrawable
    function test_admin() {

    }

    // Getters should always return the correct values
    function test_getters() {

    }
}