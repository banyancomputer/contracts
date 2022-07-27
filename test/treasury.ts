import { Authority } from "../types"; // just to redeclare this test scope
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Treasury", async () => {

  before(async function () {
    this.ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    this.ERC721Mock = await ethers.getContractFactory("ERC721Mock");
    this.ERC1155Mock = await ethers.getContractFactory("ERC1155Mock");

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
    this.erc721Mock = await this.ERC721Mock.deploy();
    this.erc1155Mock = await this.ERC1155Mock.deploy();
    this.authority = await this.Authority.deploy(this.ownerAddress, this.ownerAddress, this.ownerAddress, this.ownerAddress);
    this.treasury = await this.Treasury.deploy(this.authority.address);

    // Set up treasury vault
    await this.authority.pushVault(this.treasury.address, true);
    expect(await this.authority.vault()).to.equal(this.treasury.address);

    this.escrow = await this.Escrow.deploy(this.authority.address);
    await this.escrow.deployed();

    // ERC20Mock stuff
    const approve = await this.erc20Mock.approve(this.treasury.address, 100000);
    await approve.wait();
    const transfer = await this.erc20Mock.transfer(this.executorAddress, 100000);
    await transfer.wait();
    const approveExecutor = await this.erc20Mock.connect(this.executor).approve(this.treasury.address, 10000);
    await approveExecutor.wait();

    // ERC721Mock stuff
    const mintOwner = await this.erc721Mock.mint(this.ownerAddress);
    await mintOwner.wait();
    // console.log(await this.erc721Mock.ownerOf(1));
    const mintExecutor = await this.erc721Mock.mint(this.executorAddress);
    await mintExecutor.wait();
    const approveOwner721 = await this.erc721Mock.setApprovalForAll(this.treasury.address, true);
    await approveOwner721.wait();
    const approveExecutor721 = await this.erc721Mock.connect(this.executor).setApprovalForAll(this.treasury.address, true);
    await approveExecutor721.wait();

    // ERC1155Mock stuff
    const mintOwner1155 = await this.erc1155Mock.mint(this.ownerAddress, 1, 1000, ethers.BigNumber.from(1));
    await mintOwner1155.wait();
    const mintExecutor1155 = await this.erc1155Mock.mint(this.executorAddress, 1, 1000, ethers.BigNumber.from(1));
    await mintExecutor1155.wait();
    const approveOwner1155 = await this.erc1155Mock.setApprovalForAll(this.treasury.address, true);
    await approveOwner1155.wait();
    const approveExecutor1155 = await this.erc1155Mock.connect(this.executor).setApprovalForAll(this.treasury.address, true);
    await approveExecutor1155.wait();


    this.offerParams = [
      [this.erc20Mock.address], // creatorTokenAddress
      [1], //creatorTokenId - used for ERC721 and ERC1155
      [1000], //creatorTokenAmount - used for ERC20 and ERC1155
      [1], //creatorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
      this.executorAddress, // executorAddress
      [this.erc20Mock.address], // executorTokenAddress
      [1], //executorTokenId - used for ERC721 and ERC1155
      [1000], //executorTokenAmount - used for ERC20 and ERC1155
      [1], //executorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
    ];

    this.offerParams721 = [
      [this.erc721Mock.address], // creatorTokenAddress
      [0], //creatorTokenId - used for ERC721 and ERC1155
      [0], //creatorTokenAmount - used for ERC20 and ERC1155
      [3], //creatorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
      this.executorAddress, // executorAddress
      [this.erc721Mock.address], // executorTokenAddress
      [1], //executorTokenId - used for ERC721 and ERC1155
      [0], //executorTokenAmount - used for ERC20 and ERC1155
      [3], //executorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
    ];

    this.offerParams1155 = [
      [this.erc1155Mock.address], // creatorTokenAddress
      [1], //creatorTokenId - used for ERC721 and ERC1155
      [1000], //creatorTokenAmount - used for ERC20 and ERC1155
      [2], //creatorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
      this.executorAddress, // executorAddress
      [this.erc1155Mock.address], // executorTokenAddress
      [1], //executorTokenId - used for ERC721 and ERC1155
      [1000], //executorTokenAmount - used for ERC20 and ERC1155
      [2], //executorTokenType /// 1 == ERC20, 2 == ERC1155, 3 == ERC721
    ];


  });
    
  it("should be deployed", async function () {
    expect(this.escrow.address).to.not.be.undefined;
    expect(this.escrow.address).to.not.be.null;
  }); 

  it("should collect fee from ERC20 deposit", async function () {

    const offer = await this.escrow.startOffer(...this.offerParams);
    await offer.wait();    

    expect(await this.treasury.getTreasuryBalance(this.erc20Mock.address, 1, 0)).to.equal(2);
  });

});


