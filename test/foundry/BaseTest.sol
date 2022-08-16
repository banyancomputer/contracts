// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Utilities} from "./utils/Utilities.sol";

contract BaseTest is Test {
    Utilities internal utils;

    address payable[] users;
    uint256 numOfUsers;

    function preSetup(uint _numOfUsers) internal {
        numOfUsers = _numOfUsers;
    }

    function setUp() public virtual {
        // setup utils
        utils = new Utilities();

        // setup users
        users = utils.createUsers(numOfUsers);
    }

    function runTest() public {
        // run the exploit
        exploit();

        // verify the exploit
        success();
    }

    function exploit() internal virtual {
        /* IMPLEMENT YOUR EXPLOIT */
    }

    function success() internal virtual {
        /* IMPLEMENT YOUR EXPLOIT */
    }
}