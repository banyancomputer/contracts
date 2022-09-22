// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "hardhat/console.sol";

contract Treasury is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, ERC20Upgradeable, UUPSUpgradeable {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ========== EVENTS ========== */

    event DepositERC20(address indexed token, uint256 amount);

    event WithdrawERC20(address indexed token, address indexed recipient, uint256 amount);

    event NewPerformanceFee(uint256 oldFee, uint256 newFee);

    /* ========== STATE VARIABLES ========== */

    mapping(address => bool) public authorized;

    // Fee - default 0.1%
    uint256 public fee = 10; // 1 == 0.01%
    uint256 public feeDivisor = 10000;

    // addresses
    address public admin;
    address public escrow;

    error UNAUTHORIZED();

    /* ========== INITIALIZATION ========== */

    function _initialize(address _admin, address _escrow) public initializer()
    {
        require(_admin != address(0), "0 Address Revert");
        require(_escrow != address(0), "0 Address Revert");
        
        __ReentrancyGuard_init();
        __Ownable_init();
        admin = msg.sender;
        transferOwnership(_admin);
        
        escrow = _escrow;

        authorized[_admin] = true;
        authorized[_escrow] = true;
    }

    function _authorizeUpgrade(address) internal override onlyAdmin() {}

    /* ========== Modifiers ========== */

    modifier onlyAdmin {
	    if (msg.sender != admin) revert UNAUTHORIZED();
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
        IERC20(_token).safeTransferFrom(_sender, address(this), _amount);
        emit DepositERC20(_token, _amount);
    }

    /**
     * @notice allow approved address to withdraw from reserves
     * @param _token address
     * @param _creator address
     * @param _creatorCounterpart uint256
     * @param _provider address
     * @param _providerCounterpart uint256
     * @param _cut uint256     
     */
    function withdraw(address _token, address _creator, uint256 _creatorCounterpart, address _provider, uint256 _providerCounterpart, uint256 _cut) external {
        require(authorized[msg.sender] == true, "Not approved"); // check if it's escrow's contract calling
      
        // send the cut to the provider based on success rate + his counterpart - the fee
        uint256 providerPayment = _cut + _providerCounterpart - getFee(_providerCounterpart);
        IERC20(_token).safeTransferFrom(address(this), _provider, providerPayment);
        emit WithdrawERC20(_token, _provider, providerPayment);


        // send the refund to offer creator - the fee
        // ? is this a noticeably larger amount of gas spend than just saying "i'd like to withdraw my USDC, and i'd like to mark the client's portion of USDC as available to withdraw from the treasury, but not actually transfer the funds over to their account" ?
        uint256 refund = _creatorCounterpart - _cut - getFee(_creatorCounterpart);
        IERC20(_token).safeTransferFrom(address(this), _creator, refund);
        emit WithdrawERC20(_token, _creator, refund);

    }

    /* ========== GOV ONLY ========== */
    
     function transferAdmin(address _address) public onlyAdmin {
        admin = _address;
    }

    function setAuthorized(address _address, bool _status) public onlyAdmin {
        authorized[_address] = _status;
    }

    function setFee(uint256 _fee) public onlyAdmin {
        require(_fee < 10000, "_fee must be less than 100%");
        emit NewPerformanceFee(fee, _fee);
        fee = _fee; 
    }

    function toAdmin(address _token, uint256 _amount) public onlyAdmin {
        IERC20(_token).safeTransferFrom(address(this), admin, _amount);
    }

    /*****************************************************************/

                        /* VIEW FUNCTIONS */

    /*****************************************************************/

    function getTokenBalance(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function getFee(uint256 _amount) public view returns (uint256) {
        return (_amount * fee) / feeDivisor;
    }

    fallback() external payable {}

    receive() payable external {}

}