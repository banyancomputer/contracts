// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract Proofs is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;
    uint256 private fee;

    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xF1a252307Ff9F3fbB9598c9a181385122948b8Ae);
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    uint256 private offerId;
    struct Deal {
        uint256 offerId;
        uint256 deal_start_block;
        uint256 deal_length_in_blocks;
        uint256 proof_frequency_in_blocks;
        uint256 price;
        uint256 collateral;
        address erc20_token_denomination;
        string ipfs_file_cid; 
        uint256 file_size;
        string blake3_checksum;
    }
    mapping (uint256 => Deal) public deals;
    mapping (uint256 => mapping (uint256 => uint256)) public proofblocks;

    struct ResponseData {
        uint256 offer_id;
        uint256 success_count;
        uint256 num_windows;
        uint256 status;
        string result;
    }
    mapping(uint256 => ResponseData) public responses;

    event RequestVerification(bytes32 indexed requestId, uint256 offerId);
    event ProofAdded(uint256 indexed offerId, uint256 indexed blockNumber, bytes proof);

    function save_proof (bytes calldata _proof, uint256 _offerId, uint256 target_window) public {
        proofblocks[_offerId][target_window] = block.number;
        emit ProofAdded(_offerId, block.number, _proof);
    }

    //  PART 2

    function requestVerification(string memory _jobId, string memory _blocknum, string memory _offerid) public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(_jobId), address(this), this.fulfill.selector);
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
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }

    function stringToBytes32(string memory source) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        assembly {
            // solhint-disable-line no-inline-assembly
            result := mload(add(source, 32))
        }
    }

    /*****************************************************************/

                        /* VIEW FUNCTIONS */

    /*****************************************************************/

    function createOffer (Deal calldata _deal) public {
        deals[_deal.offerId] = _deal;
    }

    function getDeal(uint256 _offerId) public view returns (Deal memory) {
        return deals[_offerId];
    }
    function getDealStartBlock(uint256 _offerId) public view returns (uint256) {
        return deals[_offerId].deal_start_block;
    }
    function getDealLengthInBlocks(uint256 _offerId) public view returns (uint256) {
        return deals[_offerId].deal_length_in_blocks;
    }
    function getProofFrequencyInBlocks(uint256 _offerId) public view returns (uint256) {
        return deals[_offerId].proof_frequency_in_blocks;
    }
    function getPrice(uint256 _offerId) public view returns (uint256) {
        return deals[_offerId].price;
    }
    function getCollateral(uint256 _offerId) public view returns (uint256) {
        return deals[_offerId].collateral;
    }
    function getErc20TokenDenomination(uint256 _offerId) public view returns (address) {
        return deals[_offerId].erc20_token_denomination;
    }
    function getIpfsFileCid(uint256 _offerId) public view returns (string memory) {
        return deals[_offerId].ipfs_file_cid;
    }
    function getFileSize(uint256 _offerId) public view returns (uint256) {
        return deals[_offerId].file_size;
    }
    function getBlake3Checksum(uint256 _offerId) public view returns (string memory) {
        return deals[_offerId].blake3_checksum;
    }
    function getProofBlock(uint256 _offerId, uint256 window_num) public view returns (uint256) {
        return proofblocks[_offerId][window_num]; 
    }
}