// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HookList} from "../types/HookList.sol";

library HookListLib {
    uint256 private constant DYNAMIC_FEE_FLAG_METADATA = 1;

    uint256 private constant DYNAMIC_FEE_FLAG_IN_MODULE = 1 << 7;
    uint256 private constant USE_DELEGATE_FLAG_IN_MODULE = 1 << 6;

    uint256 private constant MODULE_INDEX_MASK = 0x3F; // 0011 1111

    /*
        HookList is a structure that implements compressed list of modules connected to the hook.

        One top byte used to encode additional metadata.
        Each following byte contains: 1 bit as dynamicFee flag, 1 bit as useDelegate flag, 6 bits for  global index

        | metadata | module31 | module30 | ... | module0 |
            8 bits     8 bits     8 bits          8 bits

        Each module slot contains:
        | useDynamicFee | useDelegate | global module index |
            1 bit          1 bit            6 bits
    */

    /// @dev Inserts a module in a HookList structure at position `indexInList`
    function insertModule(
        HookList config,
        uint256 indexInList,
        uint256 moduleIndex,
        bool useDelegate,
        bool useDynamicFee
    ) internal pure returns (HookList) {
        if (indexInList > 0) {
            // we do not allow to create gaps in list
            uint256 previousModule = indexInList - 1;
            uint256 moduleInfo = getModuleRaw(config, previousModule);
            require(moduleInfo != 0);
        }

        if (indexInList < 30) {
            // check if we have free place
            uint256 moduleInfo = getModuleRaw(config, 30);
            require(moduleInfo == 0);

            // shift next modules to create free gap
            uint256 mask;
            assembly {
                mask := shl(mul(8, add(indexInList, 1)), not(0))
                mask := shr(8, mask)

                let nextModules := and(config, mask)
                config := and(config, not(mask))
                config := or(config, shl(8, nextModules))
            }
        }

        assembly {
            // encoding info about module
            // moduleInfo = [useDynamicFee_1bit.useDelegate_1bit.moduleIndex_6bits], 8 bits
            let moduleInfo := or(and(0x3F, moduleIndex), shl(6, useDelegate))
            moduleInfo := or(moduleInfo, shl(7, useDynamicFee))
            config := or(
                config,
                shl(mul(indexInList, 8), and(0xFF, moduleInfo))
            )
        }

        if (useDynamicFee) {
            if (!hasDynamicFee(config)) {
                uint256 metadata = getMetadata(config) |
                    DYNAMIC_FEE_FLAG_METADATA;
                config = setMetadata(config, metadata);
            }
        }

        return config;
    }

    /// @dev Removes a module from a HookList structure
    function removeModule(
        HookList config,
        uint256 indexInList
    ) internal pure returns (HookList) {
        require(indexInList < 31);

        uint256 mask;
        assembly {
            // get a mask for next modules in list
            mask := shl(mul(8, add(indexInList, 1)), not(0))
            mask := shr(8, mask)

            // shift next modules to the right
            let nextModules := and(shr(8, and(config, mask)), mask)
            config := and(config, not(mask))
            config := or(config, nextModules)
        }

        uint256 metadata = getMetadata(config);
        if (metadata & DYNAMIC_FEE_FLAG_METADATA != 0) {
            if (!_hasDynamicFeeModules(config)) {
                metadata = metadata ^ DYNAMIC_FEE_FLAG_METADATA;
                config = setMetadata(config, metadata);
            }
        }

        return config;
    }

    function hasActiveModules(HookList config) internal pure returns (bool) {
        // check rightmost module (module0)
        // we do not allow to create gaps, so it must be active if we have active modules at all
        uint256 module0;
        assembly {
            module0 := and(config, 0xFF)
        }
        return module0 != 0;
    }

    /// @dev Checks DYNAMIC_FEE_FLAG in metadata
    function hasDynamicFee(HookList config) internal pure returns (bool) {
        return getMetadata(config) & DYNAMIC_FEE_FLAG_METADATA != 0;
    }

    /// @dev Checks if HookList has any modules with dynamic fee
    function _hasDynamicFeeModules(
        HookList config
    ) private pure returns (bool) {
        bool result;

        for (uint256 i; i < 31; i++) {
            uint256 moduleInfo = getModuleRaw(config, i);
            if (moduleInfo == 0) break;

            if (moduleInfo & DYNAMIC_FEE_FLAG_IN_MODULE != 0) {
                result = true;
                break;
            }
        }
        return result;
    }

    /// @dev Extracts metadata from the HookList
    function getMetadata(
        HookList config
    ) internal pure returns (uint256 metadata) {
        assembly {
            metadata := byte(0, config) // get topmost byte
        }
    }

    /// @dev Updates metadata in HookList
    function setMetadata(
        HookList config,
        uint256 metadata
    ) internal pure returns (HookList) {
        assembly {
            config := and(config, not(shl(248, 0xFF))) // clear prev value
            config := or(config, shl(248, metadata)) // set new value
        }
        return config;
    }

    function getModule(
        HookList hookList,
        uint256 index
    )
        internal
        pure
        returns (
            uint256 moduleIndex,
            bool implementsDynamicFee,
            bool useDelegate
        )
    {
        // each byte contains: 6 bits for index, 1 bit as dynamicFee flag, 1 bit as useDelegate flag
        // so we can have only 64 module total
        uint256 moduleData = getModuleRaw(hookList, index);
        implementsDynamicFee = moduleData & DYNAMIC_FEE_FLAG_IN_MODULE != 0;
        useDelegate = moduleData & USE_DELEGATE_FLAG_IN_MODULE != 0;
        moduleIndex = moduleData & MODULE_INDEX_MASK;
    }

    function getModuleRaw(
        HookList hookList,
        uint256 index
    ) internal pure returns (uint256 moduleInfo) {
        assembly {
            moduleInfo := byte(sub(31, index), hookList)
        }
    }
}
