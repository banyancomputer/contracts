import { Authority } from '../types/contracts/Authority';
import { ERC20Mock } from '../types/contracts/mocks/ERC20Mock';
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Escrow", async () => {

  before(async function () {
    this.ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    this.Authority = await ethers.getContractFactory("Authority");
    this.Escrow = await ethers.getContractFactory("Escrow");
    [ this.owner, this.executor ] = await ethers.getSigners();
    this.ownerAddress = await this.owner.getAddress();
    this.executorAddress = await this.executor.getAddress();
  });

  beforeEach(async function () {
    this.erc20Mock = await this.ERC20Mock.deploy();
    this.authority = await this.Authority.deploy(this.ownerAddress, this.ownerAddress, this.ownerAddress, this.ownerAddress);
    this.escrow = await this.Escrow.deploy(this.authority.address);
    await this.escrow.deployed();

    // console.log(await this.erc20Mock.balanceOf(this.ownerAddress));
    const approve = await this.erc20Mock.approve(this.escrow.address, 10000);
    await approve.wait();

    const transfer = await this.erc20Mock.transfer(this.executorAddress, 10000);
    await transfer.wait();

    const approveExecutor = await this.erc20Mock.connect(this.executor).approve(this.escrow.address, 1000);
    await approveExecutor.wait();

    this.offerParams = [
      [this.erc20Mock.address], // creatorTokenAddress
      [1], //creatorTokenId
      [10], //creatorTokenAmount
      [1], //creatorTokenType /// 1 == ERC20
      this.executorAddress, // executorAddress
      [this.erc20Mock.address], // executorTokenAddress
      [1], //executorTokenId
      [10], //executorTokenAmount
      [1], //executorTokenType /// 1 == ERC20
    ]

  });
    
  it("should be deployed", async function () {
    expect(this.escrow.address).to.not.be.undefined;
    expect(this.escrow.address).to.not.be.null;
  }); 

  it("should start an offer", async function () {
    
    const offerId = await this.escrow.callStatic.startOffer(...this.offerParams);
    const offer = await this.escrow.startOffer(...this.offerParams);
    await offer.wait();

    expect(offerId).to.equal(1);
    expect((await this.escrow.offerPerUser(this.ownerAddress))[0]).to.equal(offerId);
  });

  it("should cancel an offer", async function () {
      const offerId = await this.escrow.callStatic.startOffer(...this.offerParams);
      const offer = await this.escrow.startOffer(...this.offerParams);
      await offer.wait();
      const cancelOfferOutcome = await this.escrow.callStatic.cancelOffer(offerId);
      const cancelOffer = await this.escrow.cancelOffer(offerId);
      await cancelOffer.wait();
      expect(cancelOfferOutcome).to.equal(true);
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


