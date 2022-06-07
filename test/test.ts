const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Escrow", async () => {

  before(async function () {
    this.Escrow = await ethers.getContractFactory("Escrow");
    [ this.owner ] = await ethers.getSigners();
    this.ownerAddress = await this.owner.getAddress();
  });

  beforeEach(async function () {
    this.escrow = await this.Escrow.deploy();
    await this.escrow.deployed();
  });
    
  it("should be deployed", async function () {
    expect(this.escrow.address).to.not.be.undefined;
    expect(this.escrow.address).to.not.be.null;
  }); 
  
});