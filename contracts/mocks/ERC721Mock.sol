// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract ERC721Mock is ERC721PresetMinterPauserAutoId {
    constructor () ERC721PresetMinterPauserAutoId("MockERC721", "MOCK", "https://mock.com/") {
    
    }
}