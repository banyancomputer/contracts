// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import { EscrowMath } from "../libraries/EscrowMath.sol";

contract Proofs is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;
    uint256 private fee;

    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xF1a252307Ff9F3fbB9598c9a181385122948b8Ae);
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    uint256 private offerId;
    
    enum OfferStatus { NON, OFFER_CREATED, OFFER_COMPLETED, OFFER_CANCELLED, OFFER_WITHDRAWN }
    enum UserStatus  { NON, OPEN, DEPOSIT, CLAIM }

    struct Deal {
        uint256 offerId;
        uint256 dealStartBlock;
        uint256 dealLengthInBlocks;
        uint256 proofFrequencyInBlocks;
        uint256 price;
        uint256 collateral;
        address erc20TokenDenomination;
        string ipfsFileCID; 
        uint256 fileSize;
        string blake3Checksum;
        OfferCounterpart creatorCounterpart;
        OfferCounterpart providerCounterpart;
        OfferStatus offerStatus;
    }

    struct OfferCounterpart {
        bytes32 commitment;
        uint256 amount;
        address partyAddress;
        UserStatus partyStatus;
    }

    struct ResponseData {
        uint256 responseOfferID;
        uint256 successCount;
        uint256 numWindows;
        uint256 status;
        string result;
    }

    mapping (uint256 => Deal) public _deals;
    mapping (uint256 => mapping (uint256 => uint256)) public _proofblocks;

    mapping(uint256 => ResponseData) public responses;

    event RequestVerification(bytes32 indexed requestId, uint256 offerId);
    event ProofAdded(uint256 indexed offerId, uint256 indexed blockNumber, bytes proof);

    function save_proof (bytes calldata _proof, uint256 _offerId, uint256 target_window) public {
        _proofblocks[_offerId][target_window] = block.number;
        emit ProofAdded(_offerId, block.number, _proof);
    }

    //  PART 2

    function requestVerification(string memory _jobId, string memory _blocknum, string memory _offerid) public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(EscrowMath.stringToBytes32(_jobId), address(this), this.fulfill.selector);
        req.add("block_num", _blocknum); // proof blocknum
        req.add("offer_id", _offerid);
        return sendChainlinkRequest(req, fee);
    }

    /**
     * Receive the response in the form of uint256
     */
    function fulfill(bytes32 requestId, uint256 _offer_id, uint256 _success_count, uint256 _num_windows, uint16 _status, string calldata _result) public recordChainlinkFulfillment(requestId) {
        emit RequestVerification(requestId, _offer_id);
        responses[_offer_id] = ResponseData(_offer_id, _success_count, _num_windows, _status, _result);
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        link.transfer(msg.sender, link.balanceOf(address(this)));
    }


    /*****************************************************************/

                        /* VIEW FUNCTIONS */

    /*****************************************************************/

    function getDeal(uint256 offerID) public view returns (Deal memory) {
        return _deals[offerID];
    }
    function getDealStartBlock(uint256 offerID) public view returns (uint256) {
        return _deals[offerID].dealStartBlock;
    }
    function getDealLengthInBlocks(uint256 offerID) public view returns (uint256) {
        return _deals[offerID].dealLengthInBlocks;
    }
    function getProofFrequencyInBlocks(uint256 offerID) public view returns (uint256) {
        return _deals[offerID].proofFrequencyInBlocks;
    }
    function getPrice(uint256 offerID) public view returns (uint256) {
        return _deals[offerID].price;
    }
    function getCollateral(uint256 offerID) public view returns (uint256) {
        return _deals[offerID].collateral;
    }
    function getErc20TokenDenomination(uint256 offerID) public view returns (address) {
        return _deals[offerID].erc20TokenDenomination;
    }
    function getIpfsFileCid(uint256 offerID) public view returns (string memory) {
        return _deals[offerID].ipfsFileCID;
    }
    function getFileSize(uint256 offerID) public view returns (uint256) {
        return _deals[offerID].fileSize;
    }
    function getBlake3Checksum(uint256 offerID) public view returns (string memory) {
        return _deals[offerID].blake3Checksum;
    }
    function getProofBlock(uint256 offerID, uint256 windowNum) public view returns (uint256) {
        return _proofblocks[offerID][windowNum]; 
    }
}