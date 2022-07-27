// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract BanyanERC20Mock is ERC20PresetFixedSupply {
    constructor () ERC20PresetFixedSupply("MockERC20", "MOCK", 1000000, msg.sender) {
    }
}