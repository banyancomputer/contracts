// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "../../contracts/Escrow.sol";
import "../../contracts/Treasury.sol";

import {Utilities} from "./utils/Utilities.sol";
import {BaseTest} from "./BaseTest.sol";
import {stdError} from "forge-std/Test.sol";

contract Test is BaseTest {

    // using Chainlink for Chainlink.Request;

    address payable governor;
    address payable guardian;
    address payable policy;
    address payable vault;
    address payable replacementGovernor;

    constructor() {
        preSetup(5);
    }

    function setUp() public override {
        super.setUp();

        //Create attacker address and two mock addresses for pools.
        governor = users[0];
        guardian = users[1];
        policy = users[2];
        vault = users[3];
        replacementGovernor = users[4];
        //Instantiate contracts

    }

    function test_Exploit() public {
        runTest();
    }

    function exploit() internal override {
        /** CODE YOUR EXPLOIT HERE */
        
        vm.prank(guardian);

    }

    function success() internal override {
        /** SUCCESS CONDITIONS */

        // Check to see if the score is as modified.
        // vm.expectEmit(governor, replacementGovernor, true);
    }

}