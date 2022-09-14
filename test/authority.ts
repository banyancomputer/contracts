const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Authority", async () => {
  
    before(async function () {
      this.Authority = await ethers.getContractFactory("Authority");
      [ this.owner, this.newGuy ] = await ethers.getSigners();
      this.ownerAddress = await this.owner.getAddress();
      this.newGuyAddress = await this.newGuy.getAddress();
    });
  
    beforeEach(async function () {
      this.authority = await this.Authority.deploy(this.ownerAddress, this.ownerAddress, this.ownerAddress, this.ownerAddress);
      await this.authority.deployed();
    });
      
    it("should be deployed", async function () {
      expect(this.authority.address).to.not.be.undefined;
      expect(this.authority.address).to.not.be.null;
    }); 
  
    it("should push a new admin - effective immediately", async function () {
      const pushAdmin = await this.authority.pushAdmin(this.newGuyAddress, true);
      await pushAdmin.wait();
      expect(await this.authority.admin()).to.equal(this.newGuyAddress);
    });
  
    it("should push a new admin - effective after a delay", async function () {
      const pushAdmin = await this.authority.pushAdmin(this.newGuyAddress, false);
      await pushAdmin.wait();
      expect(await this.authority.admin()).to.equal(this.ownerAddress);
      const pullAdmin = await this.authority.connect(this.newGuy).pullAdmin();
      await pullAdmin.wait();
      expect(await this.authority.admin()).to.equal(this.newGuyAddress);
    });
  
    it("should push a new guardian - effective immediately", async function () {
      const pushGuardian = await this.authority.pushGuardian(this.newGuyAddress, true);
      await pushGuardian.wait();
      expect(await this.authority.guardian()).to.equal(this.newGuyAddress);
    });
  
    it("should push a new guardian - effective after a delay", async function () {
      const pushGuardian = await this.authority.pushGuardian(this.newGuyAddress, false);
      await pushGuardian.wait();
      expect(await this.authority.guardian()).to.equal(this.ownerAddress);
      const pullGuardian = await this.authority.connect(this.newGuy).pullGuardian();
      await pullGuardian.wait();
      expect(await this.authority.guardian()).to.equal(this.newGuyAddress);
    });

    it("should push a new vault - effective immediately", async function () {
        const pushVault = await this.authority.pushVault(this.newGuyAddress, true);
        await pushVault.wait();
        expect(await this.authority.vault()).to.equal(this.newGuyAddress);
    });
    
    it("should push a new vault - effective after a delay", async function () {
        const pushVault = await this.authority.pushVault(this.newGuyAddress, false);
        await pushVault.wait();
        expect(await this.authority.vault()).to.equal(this.ownerAddress);
        const pullVault = await this.authority.connect(this.newGuy).pullVault();
        await pullVault.wait();
        expect(await this.authority.vault()).to.equal(this.newGuyAddress);
    });

    it("should push a new policy - effective immediately", async function () {
        const pushPolicy = await this.authority.pushPolicy(this.newGuyAddress, true);
        await pushPolicy.wait();
        expect(await this.authority.policy()).to.equal(this.newGuyAddress);
    });
    
    it("should push a new policy - effective after a delay", async function () {
        const pushPolicy = await this.authority.pushPolicy(this.newGuyAddress, false);
        await pushPolicy.wait();
        expect(await this.authority.policy()).to.equal(this.ownerAddress);
        const pullPolicy = await this.authority.connect(this.newGuy).pullPolicy();
        await pullPolicy.wait();
        expect(await this.authority.policy()).to.equal(this.newGuyAddress);
    });
    
  });
