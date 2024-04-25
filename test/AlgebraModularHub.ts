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

  it("Only pool administrator functions", async function () {
    await expect(
      algebraModularHub.connect(otherAccount).registerModule(otherAccount)
    ).to.be.revertedWith("Only pools administrator");
    await expect(
      algebraModularHub.connect(otherAccount).replaceModule(1, otherAccount)
    ).to.be.revertedWith("Only pools administrator");
    await expect(
      algebraModularHub.connect(otherAccount).insertModulesToHookLists([
        {
          selector: "0x00000001",
          indexInHookList: 1,
          moduleGlobalIndex: 1,
          useDelegate: true,
          useDynamicFee: false,
        },
      ])
    ).to.be.revertedWith("Only pools administrator");

    await expect(
      algebraModularHub.connect(otherAccount).removeModulesFromHookLists([
        {
          selector: "0x00000001",
          indexInHookList: 1,
        },
      ])
    ).to.be.revertedWith("Only pools administrator");
  });

  it("Returns 0 as defaultPluginConfig", async function () {
    expect(await algebraModularHub.defaultPluginConfig()).to.be.eq(0);
  });

  it("Reverts if getCurrentFee called", async function () {
    await expect(algebraModularHub.getCurrentFee()).to.be.revertedWith(
      "getCurrentFee: not implemented"
    );
  });

  describe("Register module", function () {
    it("Can register module", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);
      const module2 = await ModuleMock.deploy(false, false);

      await algebraModularHub.registerModule(module1);
      await algebraModularHub.registerModule(module2);

      expect(await algebraModularHub.modules(1)).to.be.eq(module1);
      expect(await algebraModularHub.modules(2)).to.be.eq(module2);
    });

    it("Cannot register module twice", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);

      await algebraModularHub.registerModule(module1);

      await expect(
        algebraModularHub.registerModule(module1)
      ).to.be.revertedWith("Already registered");
    });

    it("Cannot register too much modules", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");

      for (let i = 0; i < 63; i++) {
        const module = await ModuleMock.deploy(true, true);
        await algebraModularHub.registerModule(module);
      }

      const module63 = await ModuleMock.deploy(true, true);
      await expect(
        algebraModularHub.registerModule(module63)
      ).to.be.revertedWith("Can't add new modules anymore");
    });
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

    it("Cannot insert for incorrect selector", async function () {
      await algebraModularHub.registerModule(owner.address);

      const selector = "0x00000001";

      await expect(
        connectModuleToHook(selector, 0, 0, false, true)
      ).to.be.revertedWith("Invalid selector");
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

  describe("Replace module", function () {
    it("Can replace module", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);

      const module2 = await ModuleMock.deploy(false, false);

      const module3 = await ModuleMock.deploy(false, false);

      await algebraModularHub.registerModule(module1);
      await algebraModularHub.registerModule(module2);

      expect(await algebraModularHub.modules(1)).to.be.eq(module1);

      await algebraModularHub.replaceModule(1, module3);

      expect(await algebraModularHub.modules(1)).to.be.eq(module3);
      expect(await algebraModularHub.modules(2)).to.be.eq(module2);
    });

    it("Cannot replace module at index 0", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);

      await expect(
        algebraModularHub.replaceModule(0, module1)
      ).to.be.revertedWith("Invalid index");
    });

    it("Cannot replace not registered module", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);

      await expect(
        algebraModularHub.replaceModule(1, module1)
      ).to.be.revertedWith("Module not registered");

      await algebraModularHub.registerModule(module1);

      await expect(
        algebraModularHub.replaceModule(2, module1)
      ).to.be.revertedWith("Module not registered");
    });

    it("Cannot replace with zero address", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);

      await algebraModularHub.registerModule(module1);

      await expect(
        algebraModularHub.replaceModule(1, ethers.ZeroAddress)
      ).to.be.revertedWith("Can't replace module with zero");
    });

    it("Cannot replace with registered module", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);
      const module2 = await ModuleMock.deploy(false, false);

      await algebraModularHub.registerModule(module1);
      await algebraModularHub.registerModule(module2);

      await expect(
        algebraModularHub.replaceModule(1, module2)
      ).to.be.revertedWith("Already registered");
    });
  });

  describe("Remove module from hook list", function () {
    it("Should remove module from hook list", async function () {
      await algebraModularHub.registerModule(owner.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await connectModuleToHook(selector, 0, 1, false, true);

      const res1 = await algebraModularHub.getModuleForHookByIndex(selector, 0);

      expect(res1.moduleGlobalIndex).to.be.eq(1);
      expect(res1.implementsDynamicFee).to.be.eq(true);
      expect(res1.useDelegate).to.be.eq(false);

      await algebraModularHub.removeModulesFromHookLists([
        { selector, indexInHookList: 0 },
      ]);

      const res2 = await algebraModularHub.getModuleForHookByIndex(selector, 0);

      expect(res2.moduleGlobalIndex).to.be.eq(0);
      expect(res2.implementsDynamicFee).to.be.eq(false);
      expect(res2.useDelegate).to.be.eq(false);

      const modules = await algebraModularHub.getModulesForHook(selector);
      expect(modules.moduleGlobalIndexes.length).to.be.eq(0);
    });

    it("Should remove module from hook list with two modules", async function () {
      await algebraModularHub.registerModule(owner.address);
      await algebraModularHub.registerModule(otherAccount.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await connectModuleToHook(selector, 0, 1, false, true);
      await connectModuleToHook(selector, 1, 2, true, false);

      const res1 = await algebraModularHub.getModuleForHookByIndex(selector, 0);

      expect(res1.moduleGlobalIndex).to.be.eq(1);
      expect(res1.implementsDynamicFee).to.be.eq(true);
      expect(res1.useDelegate).to.be.eq(false);

      await algebraModularHub.removeModulesFromHookLists([
        { selector, indexInHookList: 0 },
      ]);

      const res2 = await algebraModularHub.getModuleForHookByIndex(selector, 0);

      expect(res2.moduleGlobalIndex).to.be.eq(2);
      expect(res2.implementsDynamicFee).to.be.eq(false);
      expect(res2.useDelegate).to.be.eq(true);

      const modules = await algebraModularHub.getModulesForHook(selector);
      expect(modules.moduleGlobalIndexes.length).to.be.eq(1);
    });

    it("Cannot remove not connected module", async function () {
      await algebraModularHub.registerModule(owner.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await connectModuleToHook(selector, 0, 1, false, true);

      await expect(
        algebraModularHub.removeModulesFromHookLists([
          { selector, indexInHookList: 1 },
        ])
      ).to.be.revertedWith("Module not connected");
    });

    it("Can remove from beforeInitialize hook list", async function () {
      await algebraModularHub.registerModule(owner.address);

      const selector =
        algebraModularHub.interface.getFunction("beforeInitialize").selector;

      await connectModuleToHook(selector, 0, 1, false, true);

      await algebraModularHub.removeModulesFromHookLists([
        { selector, indexInHookList: 0 },
      ]);

      const res2 = await algebraModularHub.getModuleForHookByIndex(selector, 0);

      expect(res2.moduleGlobalIndex).to.be.eq(0);
      expect(res2.implementsDynamicFee).to.be.eq(false);
      expect(res2.useDelegate).to.be.eq(false);

      const modules = await algebraModularHub.getModulesForHook(selector);
      expect(modules.moduleGlobalIndexes.length).to.be.eq(0);
    });
  });

  describe("Execute", function () {
    it("Propagates inner silent error", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);
      await algebraModularHub.registerModule(module1);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await connectModuleToHook(selector, 0, 1, false, true);

      await module1.setRevert();

      await expect(
        poolMock.pseudoSwap((2n * 1n) << 96n)
      ).to.be.revertedWithoutReason();
    });

    it("Propagates inner error with message", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);
      await algebraModularHub.registerModule(module1);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await connectModuleToHook(selector, 0, 1, false, true);

      await module1.setRevertWithMessage();

      await expect(poolMock.pseudoSwap((2n * 1n) << 96n)).to.be.revertedWith(
        "Revert in module mock"
      );
    });

    it("Can update fee value immediately", async function () {
      const ModuleMock = await ethers.getContractFactory("ModuleMock");
      const module1 = await ModuleMock.deploy(true, true);
      const module2 = await ModuleMock.deploy(true, true);
      await algebraModularHub.registerModule(module1);
      await algebraModularHub.registerModule(module2);

      const selector =
        algebraModularHub.interface.getFunction("beforeSwap").selector;

      await connectModuleToHook(selector, 0, 1, false, true);
      await connectModuleToHook(selector, 1, 2, false, true);

      await module1.setImmediatelyUpdateDynamicFee(true, true);
      await module2.setImmediatelyUpdateDynamicFee(true, true);

      await poolMock.pseudoSwap((2n * 1n) << 96n);

      expect(await module1.touchedBeforeSwap()).to.be.eq(true);
      expect(await module1.touchedAfterSwap()).to.be.eq(false);

      expect(await module2.touchedBeforeSwap()).to.be.eq(true);
      expect(await module2.touchedAfterSwap()).to.be.eq(false);

      expect(await poolMock.currentFee()).to.be.eq(600n);
    });
  });
});
