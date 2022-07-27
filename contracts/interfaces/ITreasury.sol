// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.9;

interface ITreasury {
    /* ========== EVENTS ========== */

    event DepositERC20(address indexed token, uint256 amount);

    event WithdrawERC20(address indexed token, uint256 amount);

    /* ========== FUNCTIONS ========== */
    
    function deposit(
        uint256 _amount,
        address _token,        
        address _sender) external;
}