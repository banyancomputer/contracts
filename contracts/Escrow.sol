// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./types/AccessControlled.sol";
import "./interfaces/ITreasury.sol";

contract Escrow is Context, ERC1155Holder, ERC721Holder, AccessControlled
{
    event NewOffer(address indexed creator, address indexed executor, uint256 offerId);
    event FinishOffer(address indexed executor, uint256 offerId);
    event ClaimToken(address indexed claimOwner, OfferStatus toStatus,  uint256 offerId);
    event OfferCancelled(address indexed requester, uint256 offerId);

    uint256 private _offerId;
    string private _symbol;
    mapping(uint256 => Offer) internal _transactions;
    mapping(address => uint256[]) internal _openOffers;

    uint256 private _openOfferAcc;
    uint256 private _totalOfferCompletedAcc;
    uint256 private _totalOfferClaimAcc;

    enum OfferStatus { NON, OFFER_CREATED, OFFER_COMPLETED, OFFER_CANCELLED  }
    enum UserStatus  { NON, OPEN, DEPOSIT, CLAIM }
    enum OfferType   { NON, ERC20, ERC1155, ERC721, NATIVE }

    struct OfferCounterpart {
        address contractAddr;
        bytes32 proof;
        uint256 idAsset;
        uint256 amount;
        OfferType offerorType;
        UserStatus offerorStatus;
    }
    struct Offer {
        address creator;
        address executor;
        uint256 id;
        mapping(address => OfferUser) _offerors;
        string file;
        string description;
        OfferStatus offerStatus;
    }
    struct OfferUser 
    {
         uint256[] tokenAddressIdx;
         mapping(uint256 => OfferCounterpart ) _counterpart;
    }
    constructor(address _authority) AccessControlled(IAuthority(_authority))
    {
        require(_authority != address(0));
        _openOfferAcc = 0;
        _totalOfferCompletedAcc = 0;
        _totalOfferClaimAcc = 0;
        _offerId = 0;
    }

     function startOffer( address[] memory creatorTokenAddress, uint256[] memory creatorTokenId, uint256[] memory creatorAmount, uint8[]  memory creatorTokenType,
                         address  executerAddress , address[] memory executorTokenAddress, uint256[] memory executorTokenId, uint256[] memory executorAmount, uint8[] memory executorTokenType  ) public returns(uint256)
    {
        require(executerAddress != address(0), 'EXECUTER_ADDRESS_NOT_VALID' );
        require(creatorTokenAddress.length == creatorTokenId.length && creatorTokenAddress.length ==  creatorAmount.length 
                 && creatorTokenAddress.length == creatorTokenType.length , 'CREATOR_PARMS_LEN_ERROR');
        require(executorTokenAddress.length == executorTokenId.length && executorTokenAddress.length ==  executorAmount.length 
                 && executorTokenAddress.length == executorTokenType.length , 'EXECUTER_PARMS_LEN_ERROR');

        _offerId++;
        _transactions[_offerId].id = _offerId;
        _transactions[_offerId].creator = msg.sender;
        _transactions[_offerId].executor = executerAddress;
        for (uint256 i = 0; i < creatorTokenAddress.length; i++) 
        {
            verifyOfferIntegrity(creatorTokenAddress[i], creatorTokenId[i], creatorAmount[i], creatorTokenType[i] );
            if(OfferType(creatorTokenType[i]) == OfferType.ERC20){
                verifyERC20(msg.sender, creatorTokenAddress[i], creatorAmount[i]);
            }else if(OfferType(creatorTokenType[i]) == OfferType.ERC721){
                verifyERC721(msg.sender, creatorTokenAddress[i], creatorTokenId[i]);
            }else if(OfferType(creatorTokenType[i]) == OfferType.ERC1155){
                verifyERC1155(msg.sender, creatorTokenAddress[i], creatorAmount[i], creatorTokenId[i]);
            }
            _transactions[_offerId]._offerors[msg.sender].tokenAddressIdx.push(i+1);
            _transactions[_offerId]._offerors[msg.sender]._counterpart[i+1].contractAddr = creatorTokenAddress[i];
            _transactions[_offerId]._offerors[msg.sender]._counterpart[i+1].idAsset = creatorTokenId[i];
            _transactions[_offerId]._offerors[msg.sender]._counterpart[i+1].amount  = creatorAmount[i];
            _transactions[_offerId]._offerors[msg.sender]._counterpart[i+1].offerorType = OfferType(creatorTokenType[i]);
            _transactions[_offerId]._offerors[msg.sender]._counterpart[i+1].offerorStatus = UserStatus.OPEN;
        }
        for (uint i = 0; i < executorTokenAddress.length; i++) 
        {
            verifyOfferIntegrity(executorTokenAddress[i], executorTokenId[i], executorAmount[i], executorTokenType[i] );
            if(OfferType(executorTokenType[i]) == OfferType.ERC20){
                verifyERC20(executerAddress, executorTokenAddress[i], executorAmount[i]);
            }else if(OfferType(executorTokenType[i]) == OfferType.ERC721){
                verifyERC721(executerAddress, executorTokenAddress[i], executorTokenId[i]);
            }else if(OfferType(executorTokenType[i]) == OfferType.ERC1155){
                verifyERC1155(executerAddress, executorTokenAddress[i], executorAmount[i], executorTokenId[i]);
            }
            _transactions[_offerId]._offerors[executerAddress].tokenAddressIdx.push(i+1);
            _transactions[_offerId]._offerors[executerAddress]._counterpart[i+1].contractAddr = executorTokenAddress[i];
            _transactions[_offerId]._offerors[executerAddress]._counterpart[i+1].idAsset = executorTokenId[i];
            _transactions[_offerId]._offerors[executerAddress]._counterpart[i+1].amount  = executorAmount[i];
            _transactions[_offerId]._offerors[executerAddress]._counterpart[i+1].offerorType = OfferType(executorTokenType[i]);
            _transactions[_offerId]._offerors[executerAddress]._counterpart[i+1].offerorStatus = UserStatus.OPEN;
        }
        _transactions[_offerId].offerStatus = OfferStatus.OFFER_CREATED;
        _openOffers[msg.sender].push(_offerId);
        _openOffers[executerAddress].push(_offerId);
        emit NewOffer(msg.sender, executerAddress, _offerId );
        return _offerId;
    }

    function cancelOffer(uint256 offerId) public  returns (bool)
    {
        Offer storage store = _transactions[offerId];
        require(store.offerStatus == OfferStatus.OFFER_CREATED, 'ERROR: OFFER_STATUS ISNT CREATED');
        require(store.executor == msg.sender || store.creator == msg.sender , 'ERROR: EXECUTER ISNT CREATOR OR EXECUTER');
        _transactions[offerId].offerStatus = OfferStatus.OFFER_CANCELLED;
        emit OfferCancelled(msg.sender, offerId);
        return true;
    }
    function getOffer(uint256 offerId) public view returns (address, address, uint8, string memory)
    {
        Offer storage store = _transactions[offerId];
        return (store.creator, store.executor, uint8(store.offerStatus), store.file);
    }
    
    function getOffer(uint256 offerId, address userWallet) public view returns (address[] memory, bytes32[] memory, uint8[] memory )
    {
        Offer storage store = _transactions[offerId];
        uint256[] memory tokenAddressIdx = store._offerors[userWallet].tokenAddressIdx;

        address[]  memory _offerTokenAddress = new address[](tokenAddressIdx.length);
        bytes32[]  memory _offerProof        = new bytes32[](tokenAddressIdx.length);
        uint8[]    memory _offerType         = new uint8[](tokenAddressIdx.length);

        for(uint y = 0; y < tokenAddressIdx.length; y++){
                OfferCounterpart memory tInfo = store._offerors[userWallet]._counterpart[tokenAddressIdx[y]];
                _offerTokenAddress[y]= msg.sender;
                _offerProof[y] = tInfo.proof;
                _offerType[y] = uint8(tInfo.offerorType);
        }
        return (_offerTokenAddress, _offerProof, _offerType  );
    }
    function verifyERC721 (address from, address tokenAddress, uint256 tokenId) internal view returns (bool){
        require(from == ERC721(tokenAddress).ownerOf{gas:100000}(tokenId), 'ERROR: ERR_NOT_OWN_ID_ERC721');
        require( ERC721(tokenAddress).isApprovedForAll{gas:100000}( from, address(this) ) , 'ERROR: ERR_NOT_ALLOW_TO_TRANSER_ITENS_ERC721');
        return true;
    }
    function verifyERC20 (address from, address tokenAddress, uint256 amount) internal view returns (bool){
        require(amount <= IERC20(tokenAddress).balanceOf{gas:100000}(from), 'ERROR: ERR_NOT_ENOUGH_FUNDS_ERC20');
        require(amount <= IERC20(tokenAddress).allowance{gas:100000}(from, address(this) ), 'ERROR: ERR_NOT_ALLOW_SPEND_FUNDS');
        return true;
    }
    function verifyERC1155 (address from, address tokenAddress, uint256 amount, uint256 tokenId) internal view returns (bool){
        require(tokenId > 0, 'ERROR: STAKE_ERC1155_ID_SHOULD_GREATER_THEN_0');
        require(amount > 0 && amount <= ERC1155(tokenAddress).balanceOf{gas:100000}(from, tokenId), 'ERROR: ERR_NOT_ENOUGH_FUNDS_ERC1155');
        require( ERC1155(tokenAddress).isApprovedForAll{gas:100000}( from, address(this) ) , 'ERROR: ERR_NOT_ALLOW_TO_TRANSER_ITENS_ERC1155');
        return true;
    }
    
    function verifyOfferIntegrity(address tokenAddress, uint256 tokenId,  uint256 amount, uint8 tokenType) public pure returns(bool)
    {
        require(tokenAddress != address(0), 'ERROR: CREATOR_CONTRACT_NOT_VALID' );
        require(tokenType >=0 && tokenType <= uint8(OfferType.NATIVE)  , 'ERROR: NOT_VALID_OFFER_TYPE');
        require(tokenId >= 0  , 'ERROR: TOKENID_MUST_POSITIVE');
        require(amount > 0  , 'ERROR: AMOUNT_MUST_POSITIVE');
        return true;
    }

    function offerPerUser(address u) public view returns(uint256[] memory ){
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
}
