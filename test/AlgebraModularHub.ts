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

  let connectModuleToHook: any;

  beforeEach("Load fixture", async () => {
    ({ poolMock, algebraModularHub, factoryMock, owner, otherAccount } =
      await loadFixture(deployAlgebraModularHubFixture));

    connectModuleToHook = async (
      selector: any,
      indexInHookList: number,
      moduleGlobalIndex: number,
      useDelegate: boolean,
      useDynamicFee: boolean
    ) => {
      return algebraModularHub.insertModulesToHookLists([
        {
          selector,
          indexInHookList,
          moduleGlobalIndex,
          useDelegate,
          useDynamicFee,
        },
      ]);
    };
  });

  describe("Connect module", function () {
    it("Should insert module", async function () {
      await algebraModularHub.registerModule(owner.address);
      await algebraModularHub.registerModule(otherAccount.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await connectModuleToHook(selector, 0, 1, false, true);
      await connectModuleToHook(selector, 1, 2, true, false);

      const res1 = await algebraModularHub.getModuleForHookByIndex(selector, 0);
      const res2 = await algebraModularHub.getModuleForHookByIndex(selector, 1);

      expect(res1.moduleGlobalIndex).to.be.eq(1);
      expect(res1.implementsDynamicFee).to.be.eq(true);
      expect(res1.useDelegate).to.be.eq(false);

      expect(res2.moduleGlobalIndex).to.be.eq(2);
      expect(res2.implementsDynamicFee).to.be.eq(false);
      expect(res2.useDelegate).to.be.eq(true);

      const modules = await algebraModularHub.getModulesForHook(selector);
      expect(modules.moduleGlobalIndexes.length).to.be.eq(2);

      expect(modules.moduleGlobalIndexes[0]).to.be.eq(1);
      expect(modules.hasDynamicFee[0]).to.be.eq(true);
      expect(modules.usesDelegate[0]).to.be.eq(false);

      expect(modules.moduleGlobalIndexes[1]).to.be.eq(2);
      expect(modules.hasDynamicFee[1]).to.be.eq(false);
      expect(modules.usesDelegate[1]).to.be.eq(true);
    });

    it("Should insert modules", async function () {
      await algebraModularHub.registerModule(owner.address);
      await algebraModularHub.registerModule(otherAccount.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await algebraModularHub.insertModulesToHookLists([
        {
          selector,
          indexInHookList: 0,
          moduleGlobalIndex: 1,
          useDelegate: false,
          useDynamicFee: true,
        },
        {
          selector,
          indexInHookList: 0,
          moduleGlobalIndex: 2,
          useDelegate: true,
          useDynamicFee: false,
        },
      ]);

      const res1 = await algebraModularHub.getModuleForHookByIndex(selector, 0);
      const res2 = await algebraModularHub.getModuleForHookByIndex(selector, 1);

      expect(res1.moduleGlobalIndex).to.be.eq(2);
      expect(res1.implementsDynamicFee).to.be.eq(false);
      expect(res1.useDelegate).to.be.eq(true);

      expect(res2.moduleGlobalIndex).to.be.eq(1);
      expect(res2.implementsDynamicFee).to.be.eq(true);
      expect(res2.useDelegate).to.be.eq(false);
    });

    it("Cannot connect 32 modules", async function () {
      await algebraModularHub.registerModule(owner.address);
      await algebraModularHub.registerModule(otherAccount.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      for (let i = 0; i < 31; i++) {
        await connectModuleToHook(selector, i, 1, false, true);
      }

      await expect(
        connectModuleToHook(selector, 0, 1, false, true)
      ).to.be.revertedWith("No free space in hook list");
    });

    it("Cannot insert unregistered module", async function () {
      await algebraModularHub.registerModule(owner.address);
      await algebraModularHub.registerModule(otherAccount.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await expect(
        connectModuleToHook(selector, 0, 0, false, true)
      ).to.be.revertedWith("Invalid module index");

      await expect(
        connectModuleToHook(selector, 0, 3, false, true)
      ).to.be.revertedWith("Invalid module index");
    });

    it("Cannot insert in invalid place", async function () {
      await algebraModularHub.registerModule(owner.address);
      await algebraModularHub.registerModule(otherAccount.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await connectModuleToHook(selector, 0, 1, true, false);

      await expect(
        connectModuleToHook(selector, 2, 2, true, false)
      ).to.be.revertedWith("Can't create gaps in hook list");

      await expect(
        connectModuleToHook(selector, 31, 2, true, false)
      ).to.be.revertedWith("Invalid index in list");
    });

    it("Connected module should be called", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);

      const module2 = await ModuleMock.deploy(false, false);

      await algebraModularHub.registerModule(module1);
      await algebraModularHub.registerModule(module2);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await connectModuleToHook(selector, 0, 1, false, true);
      await connectModuleToHook(selector, 1, 2, true, false); // via delegate call

      await poolMock.pseudoSwap((2n * 1n) << 96n);

      expect(await module1.touchedBeforeSwap()).to.be.eq(true);
      expect(await module1.touchedAfterSwap()).to.be.eq(false);

      expect(await poolMock.currentFee()).to.be.eq(600n);
    });
  });
});
