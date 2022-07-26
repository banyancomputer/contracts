// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.9;

interface ITreasury {
    /* ========== EVENTS ========== */

    event Deposit(address indexed token, uint256 amount);
    event DepositERC20(address indexed token, uint256 amount);
    event DepositERC721(address indexed token, uint256 indexed tokenId);
    event DepositERC1155(address indexed token, uint256[] indexed tokenIds, uint256[] amount);
    event DepositEther(uint256 amount);

    event Withdraw(address indexed token, uint256 amount);
    event WithdrawERC20(address indexed token, uint256 amount);
    event WithdrawERC721(address indexed token, uint256 indexed tokenId);
    event WithdrawERC1155(address indexed token, uint256[] indexed tokenIds, uint256[] amount);
    event WithdrawalEther(uint256 amount);

    /* ========== FUNCTIONS ========== */
    
    function deposit(uint256 _amount,
        address _token,
        uint8 _tokenType,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        address _sender) external payable;
}