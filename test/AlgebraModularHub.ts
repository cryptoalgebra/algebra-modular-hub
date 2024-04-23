import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("AlgebraModularHub", function () {
  async function deployAlgebraModularHubFixture() {
    const [owner, otherAccount] = await ethers.getSigners();

    const PoolMock = await ethers.getContractFactory("PoolMock");
    const poolMock = await PoolMock.deploy();

    const FactoryMock = await ethers.getContractFactory("FactoryMock");
    const factoryMock = await FactoryMock.deploy();

    const AlgebraModularHub = await ethers.getContractFactory(
      "AlgebraModularHub"
    );
    const algebraModularHub = await AlgebraModularHub.deploy(
      poolMock,
      factoryMock
    );

    await poolMock.setPlugin(algebraModularHub);

    return { poolMock, algebraModularHub, factoryMock, owner, otherAccount };
  }

  let poolMock: any;
  let algebraModularHub: any;
  let factoryMock: any;
  let owner: any;
  let otherAccount: any;

  beforeEach("Load fixture", async () => {
    ({ poolMock, algebraModularHub, factoryMock, owner, otherAccount } =
      await loadFixture(deployAlgebraModularHubFixture));
  });

  describe("Connect module", function () {
    it("Should connect module", async function () {
      await algebraModularHub.registerModule(owner.address);
      await algebraModularHub.registerModule(otherAccount.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await algebraModularHub.connectModuleToHook(selector, 1, false, true);
      await algebraModularHub.connectModuleToHook(selector, 2, true, false);

      const res1 = await algebraModularHub.getModuleForHookByIndex(selector, 0);
      const res2 = await algebraModularHub.getModuleForHookByIndex(selector, 1);

      expect(res1.moduleIndex).to.be.eq(1);
      expect(res1.implementsDynamicFee).to.be.eq(true);
      expect(res1.useDelegate).to.be.eq(false);

      expect(res2.moduleIndex).to.be.eq(2);
      expect(res2.implementsDynamicFee).to.be.eq(false);
      expect(res2.useDelegate).to.be.eq(true);

      const modules = await algebraModularHub.getModulesForHook(selector);
      expect(modules.moduleIndexes.length).to.be.eq(2);

      expect(modules.moduleIndexes[0]).to.be.eq(1);
      expect(modules.hasDynamicFee[0]).to.be.eq(true);
      expect(modules.usesDelegate[0]).to.be.eq(false);

      expect(modules.moduleIndexes[1]).to.be.eq(2);
      expect(modules.hasDynamicFee[1]).to.be.eq(false);
      expect(modules.usesDelegate[1]).to.be.eq(true);
    });

    it("Should insert module", async function () {
      await algebraModularHub.registerModule(owner.address);
      await algebraModularHub.registerModule(otherAccount.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await algebraModularHub.insertModulesToHookLists(
        selector,
        0,
        1,
        false,
        true
      );
      await algebraModularHub.insertModulesToHookLists(
        selector,
        0,
        2,
        true,
        false
      );

      const res1 = await algebraModularHub.getModuleForHookByIndex(selector, 0);
      const res2 = await algebraModularHub.getModuleForHookByIndex(selector, 1);

      expect(res1.moduleIndex).to.be.eq(2);
      expect(res1.implementsDynamicFee).to.be.eq(false);
      expect(res1.useDelegate).to.be.eq(true);

      expect(res2.moduleIndex).to.be.eq(1);
      expect(res2.implementsDynamicFee).to.be.eq(true);
      expect(res2.useDelegate).to.be.eq(false);
    });

    it("Cannot connect 32 modules", async function () {
      await algebraModularHub.registerModule(owner.address);
      await algebraModularHub.registerModule(otherAccount.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      for (let i = 0; i < 31; i++) {
        await algebraModularHub.connectModuleToHook(selector, 1, false, true);
      }

      await expect(
        algebraModularHub.connectModuleToHook(selector, 1, false, true)
      ).to.be.revertedWith("No free place");
    });

    it("Cannot insert unregistered module", async function () {
      await algebraModularHub.registerModule(owner.address);
      await algebraModularHub.registerModule(otherAccount.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await expect(
        algebraModularHub.insertModulesToHookLists(selector, 0, 0, false, true)
      ).to.be.revertedWithoutReason();

      await expect(
        algebraModularHub.insertModulesToHookLists(selector, 0, 3, false, true)
      ).to.be.revertedWithoutReason();
    });

    it("Cannot insert in invalid place", async function () {
      await algebraModularHub.registerModule(owner.address);
      await algebraModularHub.registerModule(otherAccount.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await algebraModularHub.insertModulesToHookLists(
        selector,
        0,
        1,
        true,
        false
      );

      await expect(
        algebraModularHub.insertModulesToHookLists(selector, 2, 2, true, false)
      ).to.be.revertedWithoutReason();

      await expect(
        algebraModularHub.insertModulesToHookLists(selector, 31, 2, true, false)
      ).to.be.revertedWithoutReason();
    });

    it("Connected module should be called", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);

      const module2 = await ModuleMock.deploy(false, false);

      await algebraModularHub.registerModule(module1);
      await algebraModularHub.registerModule(module2);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await algebraModularHub.connectModuleToHook(selector, 1, false, true);
      await algebraModularHub.connectModuleToHook(selector, 2, true, false); // via delegate call

      await poolMock.pseudoSwap((2n * 1n) << 96n);

      expect(await module1.touchedBeforeSwap()).to.be.eq(true);
      expect(await module1.touchedAfterSwap()).to.be.eq(false);

      expect(await poolMock.currentFee()).to.be.eq(600n);
    });
  });
});
