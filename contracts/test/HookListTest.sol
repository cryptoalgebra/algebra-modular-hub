// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {HookList} from "../types/HookList.sol";
import {HookListLib} from "../libraries/HookListLib.sol";

contract HookListTest {
    using HookListLib for HookList;

    function insertModule(
        HookList config,
        uint256 indexInList,
        uint256 moduleIndex,
        bool useDelegate,
        bool useDynamicFee
    ) external pure returns (HookList) {
        return
            HookListLib.insertModule(
                config,
                indexInList,
                moduleIndex,
                useDelegate,
                useDynamicFee
            );
    }

    function removeModule(
        HookList config,
        uint256 indexInList
    ) external pure returns (HookList) {
        return HookListLib.removeModule(config, indexInList);
    }

    function hasActiveModules(HookList config) external pure returns (bool) {
        return HookListLib.hasActiveModules(config);
    }

    function hasDynamicFee(HookList config) external pure returns (bool) {
        return HookListLib.hasDynamicFee(config);
    }

    function getModule(
        HookList hookList,
        uint256 index
    )
        external
        pure
        returns (
            uint256 moduleIndex,
            bool implementsDynamicFee,
            bool useDelegate
        )
    {
        return HookListLib.getModule(hookList, index);
    }

    function getModuleRaw(
        HookList hookList,
        uint256 index
    ) external pure returns (uint256 moduleInfo) {
        return HookListLib.getModuleRaw(hookList, index);
    }
}
