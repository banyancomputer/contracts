// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IEscrow.sol";
import "./interfaces/ITreasury.sol";

import { EscrowMath } from "./libraries/EscrowMath.sol";

import "hardhat/console.sol";

contract Escrow is ChainlinkClient, Initializable, ContextUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, IEscrow
{
    using Chainlink for Chainlink.Request;

    ITreasury public treasury;
    address public vault;
    address public override governor;

    uint256 private fee;

    uint256 private _offerId;
    mapping(uint256 => Deal) public _deals;
    mapping(uint256 => mapping (uint256 => uint256)) public _proofblocks;
    mapping(address => uint256[]) internal _openOffers;
    mapping(uint256 => uint256) public _proofSuccessRate; // offerId => proofSuccessRate (0-10000; 10000 = 100%)
    mapping(uint256 => ResponseData) public responses;

    uint256 private _openOfferAcc;
    uint256 private _totalOfferCompletedAcc;
    uint256 private _totalOfferClaimAcc;

    // Oracle Configuration
    address private oracle;
    bytes32 private jobId;

    enum OfferStatus { NON, OFFER_CREATED, OFFER_ACCEPTED, OFFER_ACTIVE, OFFER_COMPLETED, OFFER_FINALIZED, OFFER_TIMEDOUT, OFFER_CANCELLED }

    struct OfferCounterpart {
        bytes32 commitment;
        uint256 amount;
        address partyAddress;
    }

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
        OfferCounterpart executorCounterpart;
        OfferStatus offerStatus;
    }

    struct ResponseData {
        uint256 responseOfferID;
        uint256 successCount;
        uint256 numWindows;
        uint256 status;
        string result;
    }

    event NewOffer(address indexed creator, address indexed executor, uint256 offerId);
    event OfferJoined(uint256 offerId, address indexed executor);
    event FinishOffer(address indexed executor, uint256 offerId);
    event OfferFinalized(uint256 offerId);
    event ClaimToken(address indexed claimOwner, OfferStatus toStatus,  uint256 offerId);
    event OfferCancelled(address indexed requester, uint256 offerId);
    event RequestVerification(bytes32 indexed requestId, uint256 offerId);
    event ProofAdded(uint256 indexed offerId, uint256 indexed blockNumber, bytes proof);

    error UNAUTHORIZED();
    error AUTHORITY_INITIALIZED();

    /**
    * @notice Deploy the contract with a specified address for the Authority, the LINK and Oracle contract addresses
    * @dev Sets the storage for the specified addresses
    * @param _governor Address of the Govenor contract
    * @param _link The address of the LINK token contract
    * @param _vault The address of the Banyan vault contract
    * @param _vault The address of the treasury contract for interactions between parties
    */

    function _initialize(address _link, address _governor, address _treasury, address _vault, address _oracle) external initializer
    {
        require(_governor != address(0), "0 Address Revert");
        
        __ReentrancyGuard_init();
        __Ownable_init();
        transferOwnership(_governor);

        governor = _governor;
        vault = _vault;
        treasury = ITreasury(_treasury);
        
        setChainlinkToken(_link);
        setChainlinkOracle(_oracle);

        _openOfferAcc = 0;
        _totalOfferCompletedAcc = 0;
        _totalOfferClaimAcc = 0;
        _offerId = 0;
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    /* ========== MODIFIERS ========== */

    modifier onlyGovernor {
	    if (msg.sender != governor) revert UNAUTHORIZED();
	_;
    }

    modifier onlyExecutor(uint256 offerId) {
        require(offerId != 0, "Invalid offer id");
        Deal memory offer = _deals[offerId];
        require(offer.executorCounterpart.partyAddress == msg.sender, "Only executor");
        _;
    }
        
    modifier onlyCreator(uint256 offerId) {
        require(offerId != 0, "Invalid offer id");
        Deal memory offer = _deals[offerId];
        require(offer.creatorCounterpart.partyAddress == msg.sender, "Only creator");
        _;
    }

    modifier onlyParticipant(uint256 offerId) {
        require(offerId != 0, "Invalid offer id");
        Deal memory offer = _deals[offerId];
        require(offer.creatorCounterpart.partyAddress == msg.sender || offer.executorCounterpart.partyAddress == msg.sender, "Only creator or executor");
        _;
    }

    /* ========== Functionalities ========== */

     function startOffer(address executorAddress, uint256 dealLength, uint256 proofFrequency, uint256 bounty, uint256 collateral, address token, uint256 fileSize, string calldata cid, string calldata blake3) public payable returns(uint256)
    {
        require(executorAddress != address(0), "EXECUTER_ADDRESS_NOT_VALID");    

        _offerId++;
        _deals[_offerId].offerId = _offerId;
        _deals[_offerId].dealLengthInBlocks = dealLength;
        _deals[_offerId].proofFrequencyInBlocks = proofFrequency;
        _deals[_offerId].price = bounty;
        _deals[_offerId].collateral = collateral;
        _deals[_offerId].erc20TokenDenomination = token;
        _deals[_offerId].fileSize = fileSize;
        _deals[_offerId].ipfsFileCID = cid;
        _deals[_offerId].blake3Checksum = blake3;
        _deals[_offerId].creatorCounterpart.partyAddress = msg.sender;
        _deals[_offerId].executorCounterpart.partyAddress = executorAddress;
    
        verifyOfferIntegrity(token, bounty);
        verifyERC20(msg.sender, token, bounty);

        _deals[_offerId].creatorCounterpart.amount  = bounty;
        
        _deals[_offerId].offerStatus = OfferStatus.OFFER_CREATED;
        _openOffers[msg.sender].push(_offerId);
        _openOffers[executorAddress].push(_offerId);

        // Contract creator moves funds to Treasury
        treasury.deposit(collateral, token, msg.sender);

        emit NewOffer(msg.sender, executorAddress, _offerId );
        return _offerId;
    }

    function joinOffer(uint256 offerID) public {
        require(offerID != 0, "Invalid offer id");
        require(_deals[offerID].executorCounterpart.partyAddress == msg.sender, "Designated executor only");
        require(_deals[offerID].offerStatus == OfferStatus.OFFER_CREATED, "Offer not available");

        verifyERC20(msg.sender, _deals[_offerId].erc20TokenDenomination, _deals[_offerId].price);

        _deals[_offerId].offerStatus = OfferStatus.OFFER_ACCEPTED;

        _deals[_offerId].executorCounterpart.amount = _deals[_offerId].collateral;

        // initialize proof with current block number
        _deals[_offerId].dealStartBlock = block.number;

        treasury.deposit(_deals[_offerId].collateral, _deals[_offerId].erc20TokenDenomination, msg.sender);

        emit OfferJoined(offerID, msg.sender);
    }

    function cancelOffer(uint256 offerId) public returns (bool)
    {
        Deal storage store = _deals[offerId];
        require(store.offerStatus == OfferStatus.OFFER_CREATED, "OFFER_STATUS ISNT CREATED");
        require(store.executorCounterpart.partyAddress == msg.sender || store.creatorCounterpart.partyAddress == msg.sender , "UNAUTHORIZED");
        _deals[offerId].offerStatus = OfferStatus.OFFER_CANCELLED;
        emit OfferCancelled(msg.sender, offerId);
        return true;
    }
    
     function verifyERC20 (address from, address tokenAddress, uint256 amount) internal view returns (bool){
        require(amount <= IERC20(tokenAddress).balanceOf(from), "NOT ENOUGH ERC20");
        require(amount <= IERC20(tokenAddress).allowance(from, vault), "UNAUTHORIZED");
        return true;
    }
    
    function verifyOfferIntegrity(address tokenAddress,  uint256 amount) public pure returns(bool)
    {
        require(tokenAddress != address(0), "INVALID TOKENADDR");
        require(amount > 0  , "MUST BE > 0 AMT");
        return true;
    }

    function removeOfferForUser(address user, uint256 offerId) private returns(bool)
    {
        uint256[] memory userOffers = _openOffers[user];

        if(_openOffers[user].length == 1){
            _openOffers[user][0] = 0;
            return true;
        }
        for (uint i = 0; i<userOffers.length-1; i++){
            if(userOffers[i] == offerId ){
                 _openOffers[user][i] = _openOffers[user][userOffers.length-1];
                 _openOffers[user].pop();
                return true;
            }   
        }
        return false;
    }

    // function that saves time of proof sending
    function saveProof(bytes calldata _proof, uint256 offerId, uint256 targetWindow) public onlyExecutor(offerId) {
        require(_proof.length > 0, "No proof provided"); // check if proof is empty
        require(_deals[offerId].offerStatus == OfferStatus.OFFER_CREATED, "ERROR: OFFER_NOT_ACTIVE");
        require(block.number < _deals[offerId].dealStartBlock + _deals[offerId].dealLengthInBlocks && block.number > _deals[offerId].dealStartBlock, "Out of block timerange");

        _proofblocks[offerId][targetWindow] = block.number;
        emit ProofAdded(offerId, _proofblocks[offerId][targetWindow], _proof);
    }
 
    // get the block numbers of all proofs sent for a specific offer
    function getProofBlockNumbers(uint256 offerId) public view returns(uint256) {
        return _deals[offerId].dealLengthInBlocks;
    }
 
    /**
    * @notice Returns the address of the LINK token
    * @dev This is the public implementation for chainlinkTokenAddress, which is
    * an internal method of the ChainlinkClient contract
    */
    function getChainlinkToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    /**
    * @notice Creates a request to the specified Oracle contract address
    * @dev This function ignores the stored Oracle contract address and
    * will instead send the request to the address specified
    */

    function requestVerification(string memory _jobId, string memory _offerid) public returns (bytes32 requestId) {
        require(msg.sender == oracle, "Only Oracle");
        Chainlink.Request memory req = buildChainlinkRequest(EscrowMath.stringToBytes32(_jobId), address(this), this.fulfill.selector);
        req.addUint("block_num", block.number); // proof blocknum
        req.add("offer_id", _offerid);
        return sendChainlinkRequest(req, fee);
    }

    /**
    * @notice The fulfill method from requests created by this contract
    * @dev The recordChainlinkFulfillment protects this function from being called
    * by anyone other than the oracle address that the request was sent to. Only the oracle should be calling on this function.
    * @param requestId The ID that was generated for the request
    */    
    
    function fulfill(bytes32 requestId, uint256 offerID, uint256 successCount, uint256 numWindows, uint16 status, string calldata result) public recordChainlinkFulfillment(requestId) {
        emit RequestVerification(requestId, offerID);
        prepWithdrawal(offerID, successCount);
        require(_proofSuccessRate[offerID] > 80, "Unsuccessful redemption"); // check to make sure the proofs submitted over time reaches limit
        finalize(offerID);
        withdraw(offerID);
        responses[offerID] = ResponseData(offerID, successCount, numWindows, status, result);
    }

    /**
    * @notice Call this method if no response is received within 5 minutes
    * @param _requestId The ID that was generated for the request to cancel
    * @param _payment The payment specified for the request to cancel
    * @param _callbackFunctionId The bytes4 callback function ID specified for
    * the request to cancel
    * @param _expiration The expiration generated for the request to cancel
    */
    function cancelRequest(bytes32 _requestId, uint256 _payment, bytes4 _callbackFunctionId, uint256 _expiration) public onlyGovernor {    
        cancelChainlinkRequest(_requestId, _payment, _callbackFunctionId, _expiration);
    }

    function finalize(uint256 offerId) internal {
        _deals[offerId].offerStatus = OfferStatus.OFFER_COMPLETED;
        emit OfferFinalized(offerId);
    }

    function prepWithdrawal(uint256 offerId, uint256 successfulProofs) internal {
        _proofSuccessRate[offerId] = (successfulProofs / _deals[offerId].proofFrequencyInBlocks) * 100;
    }

    function withdraw(uint256 offerId) internal {

        uint256 cut = ((_proofSuccessRate[offerId] * _deals[offerId].creatorCounterpart.amount) / 100 );
        
        treasury.withdraw(
            _deals[offerId].erc20TokenDenomination,
            _deals[offerId].creatorCounterpart.partyAddress, 
            _deals[offerId].creatorCounterpart.amount,
            _deals[offerId].executorCounterpart.partyAddress, 
            _deals[offerId].executorCounterpart.amount,
            cut
            );

    }

    /* ========== GOV ONLY ========== */
    function setGovernor(address _governor) internal {
        governor = _governor;
        emit AuthorityUpdated(governor);
    }

    /**
    * @notice Allows the owner to withdraw any LINK balance on the contract
    */
    function withdrawLink() public onlyGovernor {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }

    function setTreasury(address _treasury) public onlyGovernor {
        require(_treasury != address(0), "INVALID ADDRESS");
        treasury = ITreasury(_treasury);
    }

    /*****************************************************************/

                        /* VIEW FUNCTIONS */

    /*****************************************************************/

    function getOffer(uint256 offerId) public view returns (address, address, uint8)
    {
        Deal storage store = _deals[offerId];
        return (store.creatorCounterpart.partyAddress, store.executorCounterpart.partyAddress, uint8(store.offerStatus));
    }

    function getDeal(uint256 offerID) public view returns (Deal memory) {
        return _deals[offerID];
    }

    function offerPerUser(address user) public view returns(uint256[] memory) {
        return (_openOffers[user]);
    }

    function getDealStartBlock(uint256 offerID) public view returns (uint256) {
        return _deals[offerID].dealStartBlock;
    }
    function getDealStatus(uint256 _dealId) public view returns (uint8) {
        return uint8(_deals[_dealId].offerStatus);
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