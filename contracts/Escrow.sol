// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";


import "./types/AccessControlled.sol";
import "./interfaces/ITreasury.sol";

import "hardhat/console.sol";

contract Escrow is ChainlinkClient, ConfirmedOwner, Context, AccessControlled
{
    using Chainlink for Chainlink.Request;

    event NewOffer(address indexed creator, address indexed executor, uint256 offerId);
    event FinishOffer(address indexed executor, uint256 offerId);
    event OfferFinalized(uint256 offerId);
    event ClaimToken(address indexed claimOwner, OfferStatus toStatus,  uint256 offerId);
    event OfferCancelled(address indexed requester, uint256 offerId);
    event ProofAdded(uint256 indexed offerId, uint256 indexed blockNumber, bytes proof);

    ITreasury public treasury;

    uint256 private _offerId;
    string private _symbol;
    mapping(uint256 => Offer) internal _transactions;
    mapping(uint256 => Proof) internal _proofs;
    mapping(address => uint256[]) internal _openOffers;
    mapping(uint256 => uint256) _proofSuccessRate; // offerId => proofSuccessRate (0-100000; 100000 = 100%)

    uint256 private _openOfferAcc;
    uint256 private _totalOfferCompletedAcc;
    uint256 private _totalOfferClaimAcc;

    // Oracle Configuration
    address private oracle;
    bytes32 private jobId;
    uint256 private payment;
    string private url;
    string[] private params;
    string[] private paths;
    
    uint256 dailyBlocks;

    enum OfferStatus { NON, OFFER_CREATED, OFFER_COMPLETED, OFFER_CANCELLED, OFFER_WITHDRAWN }
    enum UserStatus  { NON, OPEN, DEPOSIT, CLAIM }

    struct OfferCounterpart {
        bytes32 commitment;
        uint256 amount;
        UserStatus offerorStatus;
    }

    struct Proof {
        uint256[] dailyProofIndex; // array of block.number
        uint256 dailyProofCount; // hack to avoid counting the proofs every time
        uint256 missedDays; // number of days without a proof
        uint256 startingBlock; // block.number at offer start
        uint256 fileCID; // CID of the file containing the proof
    }
    struct Offer {
        address token;
        address creator;
        OfferCounterpart creatorCounterpart;
        address executor;
        OfferCounterpart executorCounterpart;
        uint256 id;
        OfferStatus offerStatus;
    }

    /**
    * @notice Deploy the contract with a specified address for the Authority, the LINK and Oracle contract addresses
    * @dev Sets the storage for the specified addresses
    * @param _authority Address of the Authority contract
    * @param _link The address of the LINK token contract
    */
    constructor(address _authority, address _link) AccessControlled(IAuthority(_authority)) ConfirmedOwner(msg.sender)
    {
        require(_authority != address(0));
        
        if (_link == address(0)) {
            setPublicChainlinkToken();
        } else {
            setChainlinkToken(_link);
        }

        _openOfferAcc = 0;
        _totalOfferCompletedAcc = 0;
        _totalOfferClaimAcc = 0;
        _offerId = 0;
        dailyBlocks = 100;
        treasury = ITreasury(authority.vault());
    }

    modifier onlyExecutor(uint256 offerId) {
        require(offerId != 0, "Invalid offer id");
        Offer memory offer = _transactions[offerId];
        require(offer.executor == msg.sender, "Only executor can perform this action");
        _;
    }
        
    modifier onlyCreator(uint256 offerId) {
        require(offerId != 0, "Invalid offer id");
        Offer memory offer = _transactions[offerId];
        require(offer.creator == msg.sender, "Only creator can perform this action");
        _;
    }

    modifier onlyParticipant(uint256 offerId) {
        require(offerId != 0, "Invalid offer id");
        Offer memory offer = _transactions[offerId];
        require(offer.creator == msg.sender || offer.executor == msg.sender, "Only creator or executor can perform this action");
        _;
    }

    // TODO: refactor using eip 4626
     function startOffer(address token, uint256 creatorAmount, address  executerAddress, uint256 executorAmount, uint256 cid) public payable returns(uint256)
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

        // initialize proof with current block number
        _proofs[_offerId].startingBlock = block.number;
        _proofs[_offerId].dailyProofIndex.push(block.number); // TODO: get rid of costly push (maybe use struct?)
        _proofs[_offerId].fileCID = cid;
        _proofs[_offerId].dailyProofCount = 0;
        _proofs[_offerId].missedDays = 0;

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
    function getOffer(uint256 offerId) public view returns (address, address, uint8)
    {
        Offer storage store = _transactions[offerId];
        return (store.creator, store.executor, uint8(store.offerStatus));
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

    // function that saves time of proof sending
    function saveProof(uint256 offerId, bytes memory _proof) public onlyExecutor(offerId) {
        require(_proof.length > 0); // check if proof is empty
        require(_transactions[offerId].offerStatus == OfferStatus.OFFER_CREATED, 'ERROR: OFFER_NOT_ACTIVE');

        // get latest proof array index
        uint256 lastProofIndex = _proofs[offerId].dailyProofCount;

        // check how many blocks has passed
        uint256 blocksPassed = block.number - _proofs[offerId].dailyProofIndex[lastProofIndex];

        // save the number of days passed based without sending proofs (if any, solidity always rounds down)
        _proofs[offerId].missedDays += blocksPassed / dailyBlocks;    
        
        // add today's proof, current block number and increment proof count
        _proofs[offerId].dailyProofIndex.push(block.number);
        _proofs[offerId].dailyProofCount++;

        // using logs to save storage space costs - read it using ethers.js' getLogs()
        emit ProofAdded(offerId, block.number, _proof);
    }
 
    // get the block numbers of all proofs sent for a specific offer
    function getProofBlockNumbers(uint256 offerId) public view returns(uint256[] memory) {
        return _proofs[offerId].dailyProofIndex;
    }

    function setDailyBlocks(uint256 _dailyBlocks) public onlyGovernor {
        require(_dailyBlocks > 0, 'ERROR: DAILY_BLOCKS_MUST_POSITIVE');
        dailyBlocks = _dailyBlocks;
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
    * @param _oracle The Oracle contract address to send the request to
    * @param _jobId The bytes32 JobID to be executed (??)
    * @param _payment The amount of LINK to be paid for the request
    * @param _url The URL to fetch data from (??)
    * @param _params The parameters to be sent to the Oracle (offerID, blockNumber)
    * @param _paths The dot-delimited paths to parse the response
    */
    function createRequestTo(address _oracle, bytes32 _jobId, uint256 _payment, string memory _url, string[] memory _params, string[] memory _paths) internal onlyGovernor returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(_jobId, address(this), this.fulfill.selector);
        req.add("param1", string(abi.encodePacked(_url, _params[0])));
        req.add("param2", string(abi.encodePacked(_url, _params[1])));
        req.add("param3", string(abi.encodePacked(_url, _params[2])));
        req.add("path_param1", _paths[0]);
        req.add("path_param2", _paths[1]);
        req.add("path_param3", _paths[2]);
        requestId = sendChainlinkRequestTo(_oracle, req, _payment);
    }

    /**
    * @notice The fulfill method from requests created by this contract
    * @dev The recordChainlinkFulfillment protects this function from being called
    * by anyone other than the oracle address that the request was sent to
    * @param _requestId The ID that was generated for the request
    * @param _param1 The answer provided by the oracle - EXAMPLE: offerId
    * @param _param2 The answer provided by the oracle - EXAMPLE: hash computation outcome
    * @param _param3 The answer provided by the oracle
    */
    function fulfill(bytes32 _requestId, uint256 _param1, uint256 _param2, uint256 _param3) public recordChainlinkFulfillment(_requestId) {
        // TODO: check if _data contains valid proof of work completion
        uint256 offerId = _param1; // EXAMPLE: the offerId is the first parameter in the response

        if (_param2 > 0 && _param3 > 0) { // just a dummy check to make sure the proof is valid
            finalize(offerId);
            prepWithdrawal(offerId, _param2);
        }
    }

    /**
    * @notice Allows the owner to withdraw any LINK balance on the contract
    */
    function withdrawLink() public onlyGovernor {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
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

    /**
    * @notice Oracle parameters for the request to be sent to the Oracle contract
    * @param _oracle The Oracle contract address to send the request to
    * @param _jobId The bytes32 JobID to be executed
    * @param _payment The amount of LINK to be paid for the request
    * @param _url The URL to fetch data from
    * @param _params The parameters to be sent to the Oracle
    * @param _paths The dot-delimited path to parse of the response
    */
    function oracleSetUp(address _oracle, bytes32 _jobId, uint256 _payment, string memory _url, string[] memory _params, string[] memory _paths) public onlyGovernor {
        oracle = _oracle;
        jobId = _jobId;
        payment = _payment;
        url = _url;
        params = _params; // needs to be dinamically obtained per offer
        paths = _paths;
    }

    function oracleRequest() public onlyGovernor returns (bytes32 requestId) {
        return createRequestTo(oracle, jobId, payment, url, params, paths);
    }

    function finalize(uint256 offerId) internal {
        _transactions[offerId].offerStatus = OfferStatus.OFFER_COMPLETED;
        emit OfferFinalized(offerId);
    }

    function prepWithdrawal(uint256 offerId, uint256 successfulProofs) internal {
        // TODO: include here any other logic to determine the amount of payment to be withdrawn
        _proofSuccessRate[offerId] = (successfulProofs / _proofs[offerId].dailyProofCount) * 100;
    }

    function withdraw(uint256 offerId) public onlyParticipant(offerId) {
        require(_transactions[offerId].offerStatus == OfferStatus.OFFER_COMPLETED, "ERROR: OFFER_NOT_COMPLETED");
        require(_proofSuccessRate[offerId] > 0, "ERROR: NO_SUCCESSFUL_PROOFS");
        require(_proofSuccessRate[offerId] < 100, "ERROR: ALL_PROOFS_SUCCESSFUL");

        uint256 cut = ((_proofSuccessRate[offerId] * _transactions[offerId].creatorCounterpart.amount) / 100 );
        
        treasury.withdraw(
            _transactions[offerId].token,
            _transactions[offerId].creator, 
            _transactions[offerId].creatorCounterpart.amount,
            _transactions[offerId].executor, 
            _transactions[offerId].executorCounterpart.amount,
            cut
            );
        
        _transactions[offerId].offerStatus = OfferStatus.OFFER_WITHDRAWN;
    }

}
