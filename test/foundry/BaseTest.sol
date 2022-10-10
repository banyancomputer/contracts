// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Utilities} from "./utils/Utilities.sol";

contract BaseTest is Test {
    Utilities internal utils;

    address payable[] public users;
    uint256 public numOfUsers;

    function preSetup(uint _numOfUsers) internal {
        numOfUsers = _numOfUsers;
    }

    function setUp() public virtual {
        // setup utils
        utils = new Utilities();

        // setup users
        users = utils.createUsers(numOfUsers);
    }

}