// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Context.sol";

import "./types/AccessControlled.sol";

import "hardhat/console.sol";

contract Treasury is Context, ERC1155Holder, ERC721Holder, AccessControlled {

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

    /* ========== DATA STRUCTURES ========== */

    enum STATUS {
        NON,
        RESERVEDEPOSITOR,
        RESERVESPENDER
    }

    enum TokenType   { 
        NON, 
        ERC20, 
        ERC1155, 
        ERC721, 
        NATIVE 
    }


    /* ========== STATE VARIABLES ========== */

    string internal notApproved = "Treasury: not approved";
    string internal invalidToken = "Treasury: invalid token";

    mapping(STATUS => mapping(address => bool)) public permissions;

    // Fee - default 0.1%
    uint256 public fee = 10; // 1 == 0.01%
    uint256 public feeDivisor = 10000;

    // Treasury balance
    mapping(address => uint256) public erc20Treasury; // tokenAddress => feePot
    mapping(address => mapping(uint256 => uint256)) public erc1155Treasury; // tokenAddress => tokenId => feePot

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _authority
    ) AccessControlled(IAuthority(_authority)) {
        // TBD
    }


    /**
     * @notice allow address to deposit an asset 
     * @param _amount uint256
     * @param _token address
     * @param _tokenType TokenType
     * @param _tokenIds uint256[]
     * @param _amounts uint256[]
     */
    function deposit(
        uint256 _amount,
        address _token,
        uint8 _tokenType,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        address _sender
    ) external payable {        
        if (TokenType(_tokenType) == TokenType.ERC20) {
            IERC20(_token).transferFrom(_sender, address(this), _amount);
            emit DepositERC20(_token, _amount);
        } else if (TokenType(_tokenType) == TokenType.ERC1155) {
            IERC1155(_token).safeBatchTransferFrom(_sender, address(this), _tokenIds, _amounts, "");
            emit DepositERC1155(_token, _tokenIds, _amounts);
        } else if (TokenType(_tokenType) == TokenType.ERC721) {
            IERC721(_token).transferFrom(_sender, address(this), _tokenIds[0]);
            emit DepositERC721(_token, _tokenIds[0]);
        } else if (TokenType(_tokenType) == TokenType.NATIVE) {
            require(payable(_sender).send(_amount));
            emit DepositEther(msg.value);
        } else {
            revert(invalidToken);
        }

        // collect fees
        // collect fee from executor's deposit? 
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            collectFee(_token, _tokenType, _amounts[i], _tokenIds[i]);
        }
        
    }

    /**
     * @notice allow approved address to withdraw from reserves
     * @param _amount uint256
     * @param _token address
     * @param _tokenType TokenType
     * @param _tokenIds uint256[]
     * @param _amounts uint256[
     */
    function withdraw(uint256 _amount, address _token, uint8 _tokenType, uint256[] memory _tokenIds, uint256[] memory _amounts) external {
        require(permissions[STATUS.RESERVESPENDER][msg.sender], notApproved);

        if (TokenType(_tokenType) == TokenType.ERC20) {
            IERC20(_token).transferFrom(address(this), msg.sender, _amount);
            emit WithdrawERC20(_token, _amount);
        } else if (TokenType(_tokenType) == TokenType.ERC1155) {
            IERC1155(_token).safeBatchTransferFrom(address(this), msg.sender, _tokenIds, _amounts, "");
            emit WithdrawERC1155(_token, _tokenIds, _amounts);
        } else if (TokenType(_tokenType) == TokenType.ERC721) {
            IERC721(_token).transferFrom(address(this), msg.sender, _tokenIds[0]);
            emit WithdrawERC721(_token, _tokenIds[0]);
        } else if (TokenType(_tokenType) == TokenType.NATIVE) {
            require(payable(msg.sender).send(_amount));
            emit WithdrawalEther(_amount);
        } else {
            revert(invalidToken);
        }
    }

    receive() external payable {
        emit DepositEther(msg.value);
    }
    
     function setPermission(
        STATUS _status,
        address _address,
        bool _permission
    ) public onlyGovernor {
        permissions[_status][_address] = _permission;
    }

    function getTokenBalance(address _token, uint8 _tokenType, uint256 _tokenId) public view returns (uint256) {

        if (TokenType(_tokenType) == TokenType.ERC20) {
            return IERC20(_token).balanceOf(address(this));
        } else if (TokenType(_tokenType) == TokenType.ERC1155) {
            return IERC1155(_token).balanceOf(address(this), _tokenId);
        } else if (TokenType(_tokenType) == TokenType.ERC721) {
            return IERC721(_token).balanceOf(address(this));
        } else if (TokenType(_tokenType) == TokenType.NATIVE) {
            return address(this).balance;
        } else {
            revert(invalidToken);
        }
    }

    function collectFee(address _token, uint8 _tokenType, uint256 _amout, uint256 _tokenId) internal {     
        uint256 _fee = (_amout * fee) / feeDivisor;
        if (TokenType(_tokenType) == TokenType.ERC20) {
            erc20Treasury[_token] += _fee;
        } else if (TokenType(_tokenType) == TokenType.ERC1155) {
            erc1155Treasury[_token][_tokenId] += _fee;
        } else if (TokenType(_tokenType) == TokenType.ERC721) {
            // TBD
        } else if (TokenType(_tokenType) == TokenType.NATIVE) {
            // TBD
        } else {
            revert(invalidToken);
        }

    }

    function setFee(uint256 _fee) public onlyGovernor {
        require(_fee < 10000); // _fee must be less than 100%
        fee = _fee;
    }

    function getTreasuryBalance(address _token, uint8 _tokenType, uint256 _tokenId) public view returns (uint256) {
        if (TokenType(_tokenType) == TokenType.ERC20) {
            return erc20Treasury[_token];
        } else if (TokenType(_tokenType) == TokenType.ERC1155) {
            return erc1155Treasury[_token][_tokenId];
        } else if (TokenType(_tokenType) == TokenType.ERC721) {
            return 0; // TBD
        } else if (TokenType(_tokenType) == TokenType.NATIVE) {
            return 0; // TBD
        } else {
            revert(invalidToken);
        }
    }
}