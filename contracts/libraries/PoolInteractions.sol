// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAlgebraPool} from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";
import {IAlgebraPlugin} from "@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol";
import {Plugins} from "@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol";

library PoolInteractions {
    uint256 internal constant BEFORE_INIT_STUB_FLAG = 0xff;

    function setFee(address poolAddress, uint16 value) internal {
        IAlgebraPool(poolAddress).setFee(value);
    }

    /// @dev Should be used carefully because of read-only-reentrancy
    function getFee(address poolAddress) internal view returns (uint16) {
        (, , uint16 lastFee, , , ) = IAlgebraPool(poolAddress).globalState();
        return lastFee;
    }

    /// @dev Should be used carefully because of read-only-reentrancy
    function isHookActivated(
        address poolAddress,
        bytes4 selector
    ) internal view returns (bool) {
        uint8 pluginConfig = _getPluginConfig(poolAddress);
        return Plugins.hasFlag(pluginConfig, flagForHook(selector));
    }

    function activateHook(address pool, bytes4 selector) internal {
        uint8 pluginConfig = _getPluginConfig(pool);
        uint256 flag = flagForHook(selector);
        require(flag != 0 && flag != BEFORE_INIT_STUB_FLAG, "Invalid hook");
        if (!Plugins.hasFlag(pluginConfig, flag)) {
            pluginConfig |= uint8(flag);
            _setPluginConfig(pool, pluginConfig);
        }
    }

    function deactivateHook(address pool, bytes4 selector) internal {
        uint8 pluginConfig = _getPluginConfig(pool);
        uint256 flag = flagForHook(selector);
        require(flag != 0 && flag != BEFORE_INIT_STUB_FLAG, "Invalid hook");
        if (Plugins.hasFlag(pluginConfig, flag)) {
            pluginConfig ^= uint8(flag);
            _setPluginConfig(pool, pluginConfig);
        }
    }

    /// @dev returns 0 for an incorrect hook
    function flagForHook(bytes4 selector) internal pure returns (uint256) {
        uint256 flag;
        if (selector == IAlgebraPlugin.beforeInitialize.selector)
            flag = BEFORE_INIT_STUB_FLAG; // technical flag
        else if (selector == IAlgebraPlugin.afterInitialize.selector)
            flag = Plugins.AFTER_INIT_FLAG;
        else if (selector == IAlgebraPlugin.beforeSwap.selector)
            flag = Plugins.BEFORE_SWAP_FLAG;
        else if (selector == IAlgebraPlugin.afterSwap.selector)
            flag = Plugins.AFTER_SWAP_FLAG;
        else if (selector == IAlgebraPlugin.beforeModifyPosition.selector)
            flag = Plugins.BEFORE_POSITION_MODIFY_FLAG;
        else if (selector == IAlgebraPlugin.afterModifyPosition.selector)
            flag = Plugins.AFTER_POSITION_MODIFY_FLAG;
        else if (selector == IAlgebraPlugin.beforeFlash.selector)
            flag = Plugins.BEFORE_FLASH_FLAG;
        else if (selector == IAlgebraPlugin.afterFlash.selector)
            flag = Plugins.AFTER_FLASH_FLAG;

        return flag;
    }

    function _getPluginConfig(address pool) private view returns (uint8) {
        (, , , uint8 pluginConfig, , ) = IAlgebraPool(pool).globalState();
        return pluginConfig;
    }

    function _setPluginConfig(address pool, uint8 pluginConfig) private {
        IAlgebraPool(pool).setPluginConfig(pluginConfig);
    }
}
