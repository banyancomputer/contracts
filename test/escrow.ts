import { Authority } from "../types"; // just to redeclare this test scope
const { expect } = require("chai");
const { ethers } = require("hardhat");

import { mine, impersonateAccount, time } from "@nomicfoundation/hardhat-network-helpers";
const fs = require("fs");

describe("Escrow", async () => {

  before(async function () {
    // juiced accounts - used when testing with forking
    const MAINNET_JUICED_WALLET = "0x5a52E96BAcdaBb82fd05763E25335261B270Efcb"; // lots of ether, usdt, link, etc
    await impersonateAccount(MAINNET_JUICED_WALLET);

    const RINKEBY_JUICED_WALLET = "0xFED4DdB595F42a5DBf48b9f318AD9b8E2685c27b"; // lots if link
    await impersonateAccount(RINKEBY_JUICED_WALLET);
    
    this.ERC20Mock = await ethers.getContractFactory("BanyanERC20Mock");

    this.Authority = await ethers.getContractFactory("Authority");
    this.Treasury = await ethers.getContractFactory("Treasury");
    this.Escrow = await ethers.getContractFactory("Escrow");

    [ this.owner, this.executor ] = await ethers.getSigners();
    this.juicedAccountMainnet = await ethers.getSigner(MAINNET_JUICED_WALLET);
    this.juicedAccountRinkeby = await ethers.getSigner(RINKEBY_JUICED_WALLET);
    this.ownerAddress = await this.owner.getAddress();
    this.executorAddress = await this.executor.getAddress();
    

    const abiEscrow = require('../artifacts/contracts/Escrow.sol/Escrow.json').abi;
    this.EscrowInterface = new ethers.utils.Interface(abiEscrow);
  });

  beforeEach(async function () {
    this.erc20Mock = await this.ERC20Mock.deploy();
    this.authority = await this.Authority.deploy(this.ownerAddress, this.ownerAddress, this.ownerAddress, this.ownerAddress);
    this.treasury = await this.Treasury.deploy(this.authority.address);

    // Set up treasury vault
    await this.authority.pushVault(this.treasury.address, true);
    expect(await this.authority.vault()).to.equal(this.treasury.address);

    this.escrow = await this.Escrow.deploy(this.authority.address, ethers.constants.AddressZero);
    await this.escrow.deployed();

    // ERC20Mock stuff
    const approve = await this.erc20Mock.approve(this.treasury.address, 10000);
    await approve.wait();
    const transfer = await this.erc20Mock.transfer(this.executorAddress, 10000);
    await transfer.wait();
    const approveExecutor = await this.erc20Mock.connect(this.executor).approve(this.treasury.address, 1000);
    await approveExecutor.wait();

    this.offerParams = [
      this.erc20Mock.address, // creatorTokenAddress
      10, //creatorTokenAmount - used for ERC20 and ERC1155
      this.executorAddress, // executorAddress
      10, //executorTokenAmount - used for ERC20 and ERC1155
      500 // CID
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

    const offerResult = await this.EscrowInterface.decodeFunctionResult("startOffer", offerTx.logs[6].data);
    const offerId = offerResult[0].toNumber();

    expect(offerId).to.equal(1);
    expect((await this.escrow.offerPerUser(this.ownerAddress))[0]).to.equal(offerId);
  });

  it("should cancel an offer", async function () {
      // const offerId = await this.escrow.callStatic.startOffer(...this.offerParams);
      const offer = await this.escrow.startOffer(...this.offerParams);
      const offerTx = await offer.wait();

      const offerResult = await this.EscrowInterface.decodeFunctionResult("startOffer", offerTx.logs[6].data);
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
  });

  it("should store a proof", async function () {
    const file = await fs.readFileSync("./test/1");

    const offer = await this.escrow.startOffer(...this.offerParams);
    const offerTx = await offer.wait();

    const offerResult = await this.EscrowInterface.decodeFunctionResult("startOffer", offerTx.logs[6].data);
    const offerId = offerResult[0].toNumber();

    const saveProof = await this.escrow.connect(this.executor).saveProof(offerId, file);
    await saveProof.wait();

    expect(await this.escrow.getLatestProof(offerId)).to.equal("0x" + file.toString('hex'));
  });

  it("should accept proofs only from the executer", async function () {
    const file = await fs.readFileSync("./test/1");

    const offer = await this.escrow.startOffer(...this.offerParams);
    const offerTx = await offer.wait();

    const offerResult = await this.EscrowInterface.decodeFunctionResult("startOffer", offerTx.logs[6].data);
    const offerId = offerResult[0].toNumber();

    await expect(this.escrow.saveProof(offerId, file)).to.be.reverted;

    const saveProof = await this.escrow.connect(this.executor).saveProof(offerId, file);
    await saveProof.wait();

    expect(await this.escrow.getLatestProof(offerId)).to.equal("0x" + file.toString('hex'));
  });

  it("should store 5 proofs", async function () {
    const file = await fs.readFileSync("./test/1");

    const offer = await this.escrow.startOffer(...this.offerParams);
    const offerTx = await offer.wait();

    const offerResult = await this.EscrowInterface.decodeFunctionResult("startOffer", offerTx.logs[6].data);
    const offerId = offerResult[0].toNumber();

    for (let i = 0; i < 5; i++) {
      const saveProof = await this.escrow.connect(this.executor).saveProof(offerId, file);
      await saveProof.wait();
      await mine(98);
      expect(await this.escrow.getLatestProof(offerId)).to.equal("0x" + file.toString('hex'));
    }
  });

  it("should store 3 proofs and miss 2 in between", async function () {
    const file = await fs.readFileSync("./test/1");

    const offer = await this.escrow.startOffer(...this.offerParams);
    const offerTx = await offer.wait();

    const offerResult = await this.EscrowInterface.decodeFunctionResult("startOffer", offerTx.logs[6].data);
    const offerId = offerResult[0].toNumber();

    for (let i = 0; i < 5; i++) {
      const saveProof = await this.escrow.connect(this.executor).saveProof(offerId, file);
      await saveProof.wait();

      await mine(i%2 ? 97 : 100); // miss blocks every 2nd block

      expect(await this.escrow.getLatestProof(offerId)).to.equal("0x" + file.toString('hex'));
    }
  });

});