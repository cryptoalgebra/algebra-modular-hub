import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("HookList", function () {
  async function deployHookListTestFixture() {
    const [owner, otherAccount] = await ethers.getSigners();

    const HookListTest = await ethers.getContractFactory("HookListTest");
    const hookListTest = await HookListTest.deploy();

    return { hookListTest, owner, otherAccount };
  }

  let hookListTest: any;
  let owner: any;
  let otherAccount: any;

  const EMPTY_HOOK_LIST = ethers.zeroPadBytes("0x", 32);

  beforeEach("Load fixture", async () => {
    ({ hookListTest, owner, otherAccount } = await loadFixture(
      deployHookListTestFixture
    ));
  });

  describe("#insertModule", function () {
    it("Should insert module in empty list", async function () {
      const list = await hookListTest.insertModule(
        EMPTY_HOOK_LIST,
        0,
        1,
        false,
        false
      );

      const module = await hookListTest.getModule(list, 0);
      expect(module.moduleIndex).to.be.eq(1);
      expect(module.implementsDynamicFee).to.be.eq(false);
      expect(module.useDelegate).to.be.eq(false);
    });

    it("Fill list with 31 module", async function () {
      let list = EMPTY_HOOK_LIST;

      expect(await hookListTest.hasDynamicFee(list)).to.be.false;
      expect(await hookListTest.hasActiveModules(list)).to.be.false;

      for (let i = 0; i < 31; i++) {
        list = await hookListTest.insertModule(list, i, i + 1, false, false);

        const module = await hookListTest.getModule(list, i);
        expect(module.moduleIndex).to.be.eq(i + 1);
        expect(module.useDelegate).to.be.eq(false);
        expect(module.implementsDynamicFee).to.be.eq(false);

        expect(await hookListTest.hasDynamicFee(list)).to.be.false;
        expect(await hookListTest.hasActiveModules(list)).to.be.true;
      }
    });

    it("Fill list with 31 module with different options sequentially", async function () {
      let list = EMPTY_HOOK_LIST;
      let hasDynamicFee = false;
      expect(await hookListTest.hasDynamicFee(list)).to.be.eq(hasDynamicFee);
      expect(await hookListTest.hasActiveModules(list)).to.be.false;

      for (let i = 0; i < 31; i++) {
        list = await hookListTest.insertModule(
          list,
          i,
          i + 1,
          i % 2 == 0,
          i % 3 == 1
        );
        if (i % 3 == 1) hasDynamicFee = true;

        const module = await hookListTest.getModule(list, i);
        expect(module.moduleIndex).to.be.eq(i + 1);
        expect(module.useDelegate).to.be.eq(i % 2 == 0);
        expect(module.implementsDynamicFee).to.be.eq(i % 3 == 1);

        expect(await hookListTest.hasDynamicFee(list)).to.be.eq(hasDynamicFee);
        expect(await hookListTest.hasActiveModules(list)).to.be.true;
      }
    });

    it("Fills list with 31 module with different options pushing from 0", async function () {
      let list = EMPTY_HOOK_LIST;
      let hasDynamicFee = false;
      let modules = [];
      for (let i = 0; i < 31; i++) {
        list = await hookListTest.insertModule(
          list,
          0,
          i + 1,
          i % 2 == 0,
          i % 3 == 1
        );
        if (i % 3 == 1) hasDynamicFee = true;

        const module = await hookListTest.getModule(list, 0);
        expect(module.moduleIndex).to.be.eq(i + 1);
        expect(module.useDelegate).to.be.eq(i % 2 == 0);
        expect(module.implementsDynamicFee).to.be.eq(i % 3 == 1);

        expect(await hookListTest.hasDynamicFee(list)).to.be.eq(hasDynamicFee);
        expect(await hookListTest.hasActiveModules(list)).to.be.true;

        modules.push(module);
      }

      modules = modules.reverse();

      for (let i = 0; i < 31; i++) {
        const module = await hookListTest.getModule(list, i);

        expect(module.moduleIndex).to.be.eq(modules[i].moduleIndex);
        expect(module.useDelegate).to.be.eq(modules[i].useDelegate);
        expect(module.implementsDynamicFee).to.be.eq(
          modules[i].implementsDynamicFee
        );
      }
    });

    function insert(index: number, array: any[], value: any) {
      const newArray = [...array.slice(0, index), value, ...array.slice(index)];
      return newArray;
    }

    it("Inserts in random place", async function () {
      let list = EMPTY_HOOK_LIST;
      let modules = [];
      for (let i = 0; i < 15; i++) {
        list = await hookListTest.insertModule(
          list,
          i,
          i + 1,
          i % 2 == 0,
          i % 3 == 1
        );
        const module = await hookListTest.getModule(list, i);
        modules.push(module);
      }

      list = await hookListTest.insertModule(list, 7, 16, false, true);
      let module = await hookListTest.getModule(list, 7);
      modules = insert(7, modules, module);

      list = await hookListTest.insertModule(list, 11, 17, false, true);
      module = await hookListTest.getModule(list, 11);
      modules = insert(11, modules, module);

      list = await hookListTest.insertModule(list, 3, 18, false, true);
      module = await hookListTest.getModule(list, 3);
      modules = insert(3, modules, module);

      for (let i = 0; i < modules.length; i++) {
        const module = await hookListTest.getModule(list, i);

        expect(module.moduleIndex).to.be.eq(modules[i].moduleIndex);
        expect(module.useDelegate).to.be.eq(modules[i].useDelegate);
        expect(module.implementsDynamicFee).to.be.eq(
          modules[i].implementsDynamicFee
        );
      }
    });

    it("Cannot create gap", async function () {
      for (let i = 1; i < 31; i++) {
        await expect(
          hookListTest.insertModule(EMPTY_HOOK_LIST, i, 1, false, false)
        ).to.be.revertedWith("Can't create gaps in hook list");
      }
    });

    it("Cannot add 32 modules sequentially", async function () {
      let list = EMPTY_HOOK_LIST;
      for (let i = 0; i < 31; i++) {
        list = await hookListTest.insertModule(list, i, i + 1, false, false);
      }
      await expect(
        hookListTest.insertModule(EMPTY_HOOK_LIST, 31, 1, false, false)
      ).to.be.revertedWith("Invalid index");
    });

    it("Cannot add 32 modules pushing from bottom", async function () {
      let list = EMPTY_HOOK_LIST;
      for (let i = 0; i < 31; i++) {
        list = await hookListTest.insertModule(list, 0, i + 1, false, false);
      }
      await expect(
        hookListTest.insertModule(list, 0, 1, false, false)
      ).to.be.revertedWith("No free space in hook list");
    });
  });

  describe("#removeModule", function () {
    it("Can remove single module", async function () {
      let list = await hookListTest.insertModule(
        EMPTY_HOOK_LIST,
        0,
        1,
        false,
        false
      );

      list = await hookListTest.removeModule(list, 0);

      const module = await hookListTest.getModule(list, 0);
      expect(module.moduleIndex).to.be.eq(0);
      expect(module.implementsDynamicFee).to.be.eq(false);
      expect(module.useDelegate).to.be.eq(false);

      expect(await hookListTest.hasDynamicFee(list)).to.be.false;
      expect(await hookListTest.hasActiveModules(list)).to.be.false;
    });

    it("Can remove one of two modules", async function () {
      let list = await hookListTest.insertModule(
        EMPTY_HOOK_LIST,
        0,
        1,
        false,
        false
      );

      list = await hookListTest.insertModule(list, 0, 2, true, true);

      list = await hookListTest.removeModule(list, 0);

      const module = await hookListTest.getModule(list, 0);
      expect(module.moduleIndex).to.be.eq(1);
      expect(module.implementsDynamicFee).to.be.eq(false);
      expect(module.useDelegate).to.be.eq(false);

      expect(await hookListTest.hasDynamicFee(list)).to.be.false;
      expect(await hookListTest.hasActiveModules(list)).to.be.true;
    });

    it("Can remove single module with dynamic fee", async function () {
      let list = await hookListTest.insertModule(
        EMPTY_HOOK_LIST,
        0,
        1,
        true,
        false
      );

      list = await hookListTest.removeModule(list, 0);

      const module = await hookListTest.getModule(list, 0);
      expect(module.moduleIndex).to.be.eq(0);
      expect(module.implementsDynamicFee).to.be.eq(false);
      expect(module.useDelegate).to.be.eq(false);

      expect(await hookListTest.hasDynamicFee(list)).to.be.false;
      expect(await hookListTest.hasActiveModules(list)).to.be.false;
    });

    it("Can remove all modules from top to bottom", async function () {
      let list = EMPTY_HOOK_LIST;
      for (let i = 0; i < 31; i++) {
        list = await hookListTest.insertModule(list, i, i + 1, true, true);
      }

      let nextModule;
      for (let i = 30; i >= 0; i--) {
        if (i != 0) nextModule = await hookListTest.getModule(list, i - 1);

        list = await hookListTest.removeModule(list, i);
        const module = await hookListTest.getModule(list, i);
        expect(module.moduleIndex).to.be.eq(0);
        expect(module.implementsDynamicFee).to.be.eq(false);
        expect(module.useDelegate).to.be.eq(false);

        if (i != 0) {
          const _nextModule = await hookListTest.getModule(list, i - 1);
          expect(_nextModule.moduleIndex).to.be.eq(nextModule.moduleIndex);
          expect(_nextModule.implementsDynamicFee).to.be.eq(
            nextModule.implementsDynamicFee
          );
          expect(_nextModule.useDelegate).to.be.eq(nextModule.useDelegate);
        }
      }

      expect(await hookListTest.hasDynamicFee(list)).to.be.false;
      expect(await hookListTest.hasActiveModules(list)).to.be.false;
    });

    it("Can remove all modules from top bottom", async function () {
      let list = EMPTY_HOOK_LIST;
      for (let i = 0; i < 31; i++) {
        list = await hookListTest.insertModule(list, i, i + 1, true, true);
      }

      let prevModule;
      for (let i = 30; i >= 0; i--) {
        prevModule = await hookListTest.getModule(list, 1);

        list = await hookListTest.removeModule(list, 0);
        const module = await hookListTest.getModule(list, 0);
        expect(module.moduleIndex).to.be.eq(prevModule.moduleIndex);
        expect(module.implementsDynamicFee).to.be.eq(
          prevModule.implementsDynamicFee
        );
        expect(module.useDelegate).to.be.eq(prevModule.useDelegate);
      }

      expect(await hookListTest.hasDynamicFee(list)).to.be.false;
      expect(await hookListTest.hasActiveModules(list)).to.be.false;
    });

    it("Cannot remove invalid index", async function () {
      await expect(
        hookListTest.removeModule(EMPTY_HOOK_LIST, 31)
      ).to.be.revertedWith("Invalid index");
    });
  });
});
