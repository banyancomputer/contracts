// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";

contract Treasury is OwnableUpgradeable, ReentrancyGuardUpgradeable, ERC20Upgradeable {

    /* ========== EVENTS ========== */

    event DepositERC20(address indexed token, uint256 amount);

    event WithdrawERC20(address indexed token, address indexed recipient, uint256 amount);


    /* ========== DATA STRUCTURES ========== */

    enum STATUS {
        NON,
        RESERVEDEPOSITOR,
        RESERVESPENDER
    }

    /* ========== STATE VARIABLES ========== */

    string internal notApproved = "Treasury: not approved";
    string internal invalidToken = "Treasury: invalid token";

    mapping(STATUS => mapping(address => bool)) public permissions;

    // Fee - default 0.1%
    uint256 public fee = 10; // 1 == 0.01%
    uint256 public feeDivisor = 10000;

    // addresses
    address public governor;

    // Treasury balance
    mapping(address => uint256) public erc20Treasury; // tokenAddress => feePot

    error UNAUTHORIZED();

    /* ========== INITIALIZATION ========== */

    function _initialize(address _authority, address _governor) external initializer
    {
        require(_authority != address(0), "0 Address Revert");
        
        __ReentrancyGuard_init();
        __Ownable_init();
        transferOwnership(_governor);
        
        governor = _governor;
    }

    /* ========== Modifiers ========== */

    modifier onlyGovernor {
	    if (msg.sender != governor) revert UNAUTHORIZED();
	_;
    }

    /**
     * @notice allow address to deposit an asset 
     * @param _amount uint256
     * @param _token address
     * @param _sender address
     */
    function deposit(
        uint256 _amount,
        address _token,        
        address _sender
    ) external {        
        IERC20(_token).transferFrom(_sender, address(this), _amount);
        emit DepositERC20(_token, _amount);
    
        collectFee(_token, _amount);
    }

    /**
     * @notice allow approved address to withdraw from reserves ||||| TODO: wait for payment approval, @audit-issue ATM reservespender can withdraw any arbitrary amount. Need to check in on vault withdrawal.
     * @param _token address
     * @param _creator address
     * @param _creatorCounterpart uint256
     * @param _executor address
     * @param _executorCounterpart uint256
     * @param _cut uint256     
     */
    function withdraw(address _token, address _creator, uint256 _creatorCounterpart, address _executor, uint256 _executorCounterpart, uint256 _cut) external {
        require(permissions[STATUS.RESERVESPENDER][msg.sender], notApproved); // check if it's escrow's contract calling
      
        // send the cut to the executor based on success rate + his counterpart - the fee
        uint256 executorPayment = _cut + _executorCounterpart - getFee(_executorCounterpart);
        collectFee(_token, _executorCounterpart);
        IERC20(_token).transferFrom(address(this), _executor, executorPayment);
        emit WithdrawERC20(_token, _executor, executorPayment);


        // send the remainder to offer creator - the fee
        uint256 remainder = _creatorCounterpart - _cut - getFee(_creatorCounterpart);
        collectFee(_token, _creatorCounterpart); 
        IERC20(_token).transferFrom(address(this), _creator, remainder);
        emit WithdrawERC20(_token, _creator, remainder);

    }
    
     function setPermission(
        STATUS _status,
        address _address,
        bool _permission
    ) public {
        permissions[_status][_address] = _permission;
    }

    function getTokenBalance(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function collectFee(address _token, uint256 _amout) internal {             
        erc20Treasury[_token] += getFee(_amout);
    }

    function getFee(uint256 _amount) public view returns (uint256) {
        return (_amount * fee) / feeDivisor;
    }

    function setFee(uint256 _fee) public onlyGovernor {
        require(_fee < 10000, "_fee must be less than 100%");
        fee = _fee;
    }

    function getTreasuryBalance(address _token) public view returns (uint256) {
        return erc20Treasury[_token];
    }
}