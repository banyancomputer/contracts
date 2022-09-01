import { expect } from "chai";
import { ethers } from "hardhat";

describe("Treasury", async () => {

  before(async function () {
    this.ERC20Mock = await ethers.getContractFactory("BanyanERC20Mock");

    this.Authority = await ethers.getContractFactory("Authority");
    this.Treasury = await ethers.getContractFactory("Treasury");
    this.Escrow = await ethers.getContractFactory("Escrow");
    [ this.owner, this.executor ] = await ethers.getSigners();
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
    const approve = await this.erc20Mock.approve(this.treasury.address, 100000);
    await approve.wait();
    const transfer = await this.erc20Mock.transfer(this.executorAddress, 100000);
    await transfer.wait();
    const approveExecutor = await this.erc20Mock.connect(this.executor).approve(this.treasury.address, 10000);
    await approveExecutor.wait();

    this.offerParams = [
      this.erc20Mock.address, // creatorTokenAddress
      1000, //creatorTokenAmount 
      this.executorAddress, // executorAddress
      1000, //executorTokenAmount
      500 // CID 
    ];
  });
    
  it("should be deployed", async function () {
    expect(this.escrow.address).to.not.be.undefined;
    expect(this.escrow.address).to.not.be.null;
  }); 

  it("should collect fee from ERC20 deposit", async function () {

    const offer = await this.escrow.startOffer(...this.offerParams);
    await offer.wait();    

    expect(await this.treasury.getTreasuryBalance(this.erc20Mock.address)).to.equal(2);
  });

});