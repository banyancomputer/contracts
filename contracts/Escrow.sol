// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import 'solidity-bytes-utils/contracts/BytesLib.sol';
import "./types/AccessControlled.sol";
import "./interfaces/ITreasury.sol";

import "hardhat/console.sol";

contract Escrow is Context, AccessControlled
{
    using BytesLib for bytes;

    event NewOffer(address indexed creator, address indexed executor, uint256 offerId);
    event FinishOffer(address indexed executor, uint256 offerId);
    event ClaimToken(address indexed claimOwner, OfferStatus toStatus,  uint256 offerId);
    event OfferCancelled(address indexed requester, uint256 offerId);

    ITreasury public treasury;

    uint256 private _offerId;
    string private _symbol;
    mapping(uint256 => Offer) internal _transactions;
    mapping(address => uint256[]) internal _openOffers;

    uint256 private _openOfferAcc;
    uint256 private _totalOfferCompletedAcc;
    uint256 private _totalOfferClaimAcc;

    enum OfferStatus { NON, OFFER_CREATED, OFFER_COMPLETED, OFFER_CANCELLED  }
    enum UserStatus  { NON, OPEN, DEPOSIT, CLAIM }

    struct OfferCounterpart {
        bytes32 commitment;
        uint256 amount;
        UserStatus offerorStatus;
    }
    struct Offer {
        address token;
        address creator;
        OfferCounterpart creatorCounterpart;
        address executor;
        OfferCounterpart executorCounterpart;
        uint256 id;
        bytes32[20] proof;
        string description;
        OfferStatus offerStatus;
    }

    constructor(address _authority) AccessControlled(IAuthority(_authority))
    {
        require(_authority != address(0));
        _openOfferAcc = 0;
        _totalOfferCompletedAcc = 0;
        _totalOfferClaimAcc = 0;
        _offerId = 0;
        treasury = ITreasury(authority.vault());
    }

    // TODO: refactor using eip 4626
     function startOffer(address token, uint256 creatorAmount, address  executerAddress, uint256 executorAmount) public payable returns(uint256)
    {
        require(executerAddress != address(0), 'EXECUTER_ADDRESS_NOT_VALID' );    

        _offerId++;
        _transactions[_offerId].id = _offerId;
        _transactions[_offerId].token = token;
        _transactions[_offerId].creator = msg.sender;
        _transactions[_offerId].executor = executerAddress;
    
        verifyOfferIntegrity(token, creatorAmount);
        verifyERC20(msg.sender, token, creatorAmount);

        // TODO: upgrade readability and maybe gas optimization
        _transactions[_offerId].creatorCounterpart.amount  = creatorAmount;
        _transactions[_offerId].creatorCounterpart.offerorStatus = UserStatus.OPEN;
        
        verifyOfferIntegrity(token, executorAmount);
        verifyERC20(executerAddress, token, executorAmount);
           
        _transactions[_offerId].executorCounterpart.amount  = creatorAmount;
        _transactions[_offerId].executorCounterpart.offerorStatus = UserStatus.OPEN;
        
        _transactions[_offerId].offerStatus = OfferStatus.OFFER_CREATED;
        _openOffers[msg.sender].push(_offerId);
        _openOffers[executerAddress].push(_offerId);

        // Start moving funds to Treasury
        treasury.deposit(creatorAmount, token, msg.sender);
        treasury.deposit(executorAmount, token, executerAddress);

        emit NewOffer(msg.sender, executerAddress, _offerId );
        return _offerId;
    }

    // TODO: add chargeback and offer dispute logic
    function cancelOffer(uint256 offerId) public  returns (bool)
    {
        Offer storage store = _transactions[offerId];
        require(store.offerStatus == OfferStatus.OFFER_CREATED, 'ERROR: OFFER_STATUS ISNT CREATED');
        require(store.executor == msg.sender || store.creator == msg.sender , 'ERROR: EXECUTER ISNT CREATOR OR EXECUTER');
        _transactions[offerId].offerStatus = OfferStatus.OFFER_CANCELLED;
        emit OfferCancelled(msg.sender, offerId);
        return true;
    }
    function getOffer(uint256 offerId) public view returns (address, address, uint8, bytes32[20] memory)
    {
        Offer storage store = _transactions[offerId];
        return (store.creator, store.executor, uint8(store.offerStatus), store.proof);
    }
    
     function verifyERC20 (address from, address tokenAddress, uint256 amount) internal view returns (bool){
        require(amount <= IERC20(tokenAddress).balanceOf(from), 'ERROR: ERR_NOT_ENOUGH_FUNDS_ERC20');
        require(amount <= IERC20(tokenAddress).allowance(from, authority.vault() ), 'ERROR: ERR_NOT_ALLOW_SPEND_FUNDS');
        return true;
    }

    
    function verifyOfferIntegrity(address tokenAddress,  uint256 amount) public pure returns(bool)
    {
        require(tokenAddress != address(0), 'ERROR: CREATOR_CONTRACT_NOT_VALID' );
        require(amount > 0  , 'ERROR: AMOUNT_MUST_POSITIVE');
        return true;
    }

    function offerPerUser(address u) public view returns(uint256[] memory ) {
        return (_openOffers[u]);
    }

    function removeOfferForUser(address u, uint256 offerId ) private returns(bool)
    {
        uint256[] memory userOffers = _openOffers[u];

        if(_openOffers[u].length == 1){
            _openOffers[u][0] = 0;
            return true;
        }
        for (uint i = 0; i<userOffers.length-1; i++){
            if(userOffers[i] == offerId ){
                 _openOffers[u][i] = _openOffers[u][userOffers.length-1];
                 _openOffers[u].pop();
                return true;
            }   
        }
        return false;
    }

    function setTreasury(address _treasury) public onlyGovernor {
        require(_treasury != address(0), 'ERROR: TREASURY_ADDRESS_NOT_VALID');
        treasury = ITreasury(_treasury);
    }

    function parseFile(bytes memory fileSlice) public pure returns(bytes32[20] memory) {
        bytes32[20] memory slices;
        uint256 length = fileSlice.length/32 > 20 ? 20 : fileSlice.length/32;
        for (uint i = 0; i < length; i++) {
            slices[i] = parseSlice(fileSlice, i); 
        }
        return slices;
    }

    // cursor is 32 bytes step
    function parseSlice(bytes memory file, uint256 cursor) public pure returns(bytes32) {        
        return bytes32(file.slice(cursor*32, 32));
    }

    function saveProof(uint256 offerId, bytes memory file) public {
        _transactions[offerId].proof = parseFile(file);
    }

    function saveProofArrayOnly(uint256 offerId, bytes32[20] memory file) public {
        _transactions[offerId].proof = file;
    }
}
