// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";

contract ERC1155Mock is ERC1155PresetMinterPauser {
    constructor () ERC1155PresetMinterPauser("https://mock.com/") {
    
    }
}