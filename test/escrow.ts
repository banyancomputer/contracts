import { Authority } from '../types/contracts/Authority';
import { ERC20Mock } from '../types/contracts/mocks/ERC20Mock';
import { EscrowInterface } from '../types/contracts/Escrow';
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Escrow", async () => {

  before(async function () {
    this.ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    this.ERC721Mock = await ethers.getContractFactory("ERC721Mock");
    this.ERC1155Mock = await ethers.getContractFactory("ERC1155Mock");

    this.Authority = await ethers.getContractFactory("Authority");
    this.Escrow = await ethers.getContractFactory("Escrow");
    [ this.owner, this.executor ] = await ethers.getSigners();
    this.ownerAddress = await this.owner.getAddress();
    this.executorAddress = await this.executor.getAddress();

    const abiEscrow = require('../artifacts/contracts/Escrow.sol/Escrow.json').abi;
    this.EscrowInterface = new ethers.utils.Interface(abiEscrow);
  });

  beforeEach(async function () {
    this.erc20Mock = await this.ERC20Mock.deploy();
    this.erc721Mock = await this.ERC721Mock.deploy();
    this.erc1155Mock = await this.ERC1155Mock.deploy();
    this.authority = await this.Authority.deploy(this.ownerAddress, this.ownerAddress, this.ownerAddress, this.ownerAddress);
    this.escrow = await this.Escrow.deploy(this.authority.address);
    await this.escrow.deployed();

    // ERC20Mock stuff
    const approve = await this.erc20Mock.approve(this.escrow.address, 10000);
    await approve.wait();
    const transfer = await this.erc20Mock.transfer(this.executorAddress, 10000);
    await transfer.wait();
    const approveExecutor = await this.erc20Mock.connect(this.executor).approve(this.escrow.address, 1000);
    await approveExecutor.wait();

    // ERC721Mock stuff
    const mintOwner = await this.erc721Mock.mint(this.ownerAddress);
    await mintOwner.wait();
    // console.log(await this.erc721Mock.ownerOf(1));
    const mintExecutor = await this.erc721Mock.mint(this.executorAddress);
    await mintExecutor.wait();
    const approveOwner721 = await this.erc721Mock.setApprovalForAll(this.escrow.address, true);
    await approveOwner721.wait();
    const approveExecutor721 = await this.erc721Mock.connect(this.executor).setApprovalForAll(this.escrow.address, true);
    await approveExecutor721.wait();

    // ERC1155Mock stuff
    const mintOwner1155 = await this.erc1155Mock.mint(this.ownerAddress, 1, 100, ethers.BigNumber.from(1));
    await mintOwner1155.wait();
    const mintExecutor1155 = await this.erc1155Mock.mint(this.executorAddress, 1, 100, ethers.BigNumber.from(1));
    await mintExecutor1155.wait();
    const approveOwner1155 = await this.erc1155Mock.setApprovalForAll(this.escrow.address, true);
    await approveOwner1155.wait();
    const approveExecutor1155 = await this.erc1155Mock.connect(this.executor).setApprovalForAll(this.escrow.address, true);
    await approveExecutor1155.wait();


    this.offerParams = [
      [this.erc20Mock.address], // creatorTokenAddress
      [1], //creatorTokenId - used for ERC721 and ERC1155
      [10], //creatorTokenAmount - used for ERC20 and ERC1155
      [1], //creatorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
      this.executorAddress, // executorAddress
      [this.erc20Mock.address], // executorTokenAddress
      [1], //executorTokenId - used for ERC721 and ERC1155
      [10], //executorTokenAmount - used for ERC20 and ERC1155
      [1], //executorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
    ];

    this.offerParams721 = [
      [this.erc721Mock.address], // creatorTokenAddress
      [0], //creatorTokenId - used for ERC721 and ERC1155
      [10], //creatorTokenAmount - used for ERC20 and ERC1155
      [3], //creatorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
      this.executorAddress, // executorAddress
      [this.erc721Mock.address], // executorTokenAddress
      [1], //executorTokenId - used for ERC721 and ERC1155
      [10], //executorTokenAmount - used for ERC20 and ERC1155
      [3], //executorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
    ];

    this.offerParams1155 = [
      [this.erc1155Mock.address], // creatorTokenAddress
      [1], //creatorTokenId - used for ERC721 and ERC1155
      [10], //creatorTokenAmount - used for ERC20 and ERC1155
      [2], //creatorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
      this.executorAddress, // executorAddress
      [this.erc1155Mock.address], // executorTokenAddress
      [1], //executorTokenId - used for ERC721 and ERC1155
      [10], //executorTokenAmount - used for ERC20 and ERC1155
      [2], //executorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
    ];


  });
    
  it("should be deployed", async function () {
    expect(this.escrow.address).to.not.be.undefined;
    expect(this.escrow.address).to.not.be.null;
  }); 

  it("should start an ERC20 collateral offer", async function () {
    
    // const offerId = await this.escrow.callStatic.startOffer(...this.offerParams);
    const offer = await this.escrow.startOffer(...this.offerParams);
    const offerTx = await offer.wait();

    const offerResult = await this.EscrowInterface.decodeFunctionResult("startOffer", offerTx.logs[0].data);
    const offerId = offerResult[0].toNumber();

    expect(offerId).to.equal(1);
    expect((await this.escrow.offerPerUser(this.ownerAddress))[0]).to.equal(offerId);
  });

  it("should start an ERC721 collateral offer", async function () {
    
    const offer = await this.escrow.startOffer(...this.offerParams721);
    const offerTx = await offer.wait();

    const offerResult = await this.EscrowInterface.decodeFunctionResult("startOffer", offerTx.logs[0].data);
    const offerId = offerResult[0].toNumber();

    expect(offerId).to.equal(1);
    expect((await this.escrow.offerPerUser(this.ownerAddress))[0]).to.equal(offerId);
  });

  it("should start an ERC1155 collateral offer", async function () {
    
    const offer = await this.escrow.startOffer(...this.offerParams1155);
    const offerTx = await offer.wait();

    const offerResult = await this.EscrowInterface.decodeFunctionResult("startOffer", offerTx.logs[0].data);
    const offerId = offerResult[0].toNumber();

    expect(offerId).to.equal(1);
    expect((await this.escrow.offerPerUser(this.ownerAddress))[0]).to.equal(offerId);
  });

  it("should cancel an offer", async function () {
      // const offerId = await this.escrow.callStatic.startOffer(...this.offerParams);
      const offer = await this.escrow.startOffer(...this.offerParams);
      const offerTx = await offer.wait();
      const offerResult = await this.EscrowInterface.decodeFunctionResult("startOffer", offerTx.logs[0].data);
      const offerId = offerResult[0].toNumber();
      
      const cancelOffer = await this.escrow.cancelOffer(offerId);
      const cancelOfferTx = await cancelOffer.wait();

      const cancelOfferResult = await this.EscrowInterface.decodeFunctionResult("cancelOffer", cancelOfferTx.logs[0].data);
      const cancelOfferBoolean = cancelOfferResult[0];

      expect(cancelOfferBoolean).to.equal(true);
      expect((await this.escrow['getOffer(uint256)'](offerId))[2]).to.equal(3); // return array position 2 is status and OfferStatus.Cancelled = 3
  });

  it("should get an offer", async function () {
    const offerId = await this.escrow.callStatic.startOffer(...this.offerParams);
    const offer = await this.escrow.startOffer(...this.offerParams);
    await offer.wait();
    const offerArray = await this.escrow['getOffer(uint256)'](offerId);
    expect(offerArray[0]).to.equal(this.ownerAddress);
    expect(offerArray[1]).to.equal(this.executorAddress);
    expect(offerArray[2]).to.equal(1);
    expect(offerArray[3]).to.equal("");
  });
});


