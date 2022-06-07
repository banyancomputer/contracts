// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract Escrow is Context, ERC1155Holder, ERC721Holder
{
    event NewOffer(address indexed creator, address indexed executor, uint256 offerId);
    event FinishOffer( address indexed executor, uint256 offerId);
    event ClaimToken(address indexed claimOwner, OfferStatus toStatus,  uint256 offerId);

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
        OfferType offerorType;
        UserStatus offerorStatus;
    }
    struct Offer {
        address creator;
        address executor;
        uint256 id;
        mapping(address => OfferUser) _offerors;
        string file;
        OfferStatus offerStatus;
    }
    struct OfferUser 
    {
         uint256[] tokenAddressIdx;
         mapping(uint256 => OfferCounterpart ) _counterpart;
    }
    constructor()
    {
        _openOfferAcc = 0;
        _totalOfferCompletedAcc = 0;
        _totalOfferClaimAcc = 0;
    }
    function cancelOffer(uint256 offerId) public  returns (bool)
    {
        Offer storage store = _transactions[offerId];
        require(store.offerStatus == OfferStatus.OFFER_CREATED, 'ERROR: OFFER_STATUS ISNT CREATED');
        require(store.executor == msg.sender || store.creator == msg.sender , 'ERROR: EXECUTER ISNT CREATOR OR EXECUTER');
        _transactions[offerId].offerStatus = OfferStatus.OFFER_CANCELLED;
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
        require(tokenId > 0  , 'ERROR: TOKENID_MUST_POSITIVE');
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
