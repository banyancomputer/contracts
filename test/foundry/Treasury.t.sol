// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "../../contracts/Escrow.sol";
import "../../contracts/Treasury.sol";

import {Utilities} from "./utils/Utilities.sol";
import {BaseTest} from "./BaseTest.sol";
import {stdError} from "forge-std/Test.sol";

contract TreasuryTest is BaseTest {

    address payable public admin;
    address payable public replacementAdmin;

    constructor() {
        preSetup(5);
    }

    

}