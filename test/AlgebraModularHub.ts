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

    const AlgebraModularHub = await ethers.getContractFactory(
      "AlgebraModularHub"
    );
    const algebraModularHub = await AlgebraModularHub.deploy(poolMock);

    await poolMock.setPlugin(algebraModularHub);

    return { poolMock, algebraModularHub, owner, otherAccount };
  }

  let poolMock: any;
  let algebraModularHub: any;
  let owner: any;
  let otherAccount: any;

  beforeEach("Load fixture", async () => {
    ({ poolMock, algebraModularHub, owner, otherAccount } = await loadFixture(
      deployAlgebraModularHubFixture
    ));
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
