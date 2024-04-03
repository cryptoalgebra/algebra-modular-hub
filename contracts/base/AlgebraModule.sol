// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAlgebraModule} from "../interfaces/IAlgebraModule.sol";
import {IAlgebraPlugin} from "@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol";

abstract contract AlgebraModule is IAlgebraModule {
    /**
     * @inheritdoc IAlgebraModule
     */
    function execute(
        bytes4 selector,
        bytes memory params,
        uint16 poolFeeCache
    ) external {
        if (selector == IAlgebraPlugin.beforeSwap.selector) {
            return _beforeSwap(params, poolFeeCache);
        }

        if (selector == IAlgebraPlugin.afterSwap.selector) {
            return _afterSwap(params, poolFeeCache);
        }

        if (selector == IAlgebraPlugin.beforeModifyPosition.selector) {
            return _beforeModifyPosition(params, poolFeeCache);
        }

        if (selector == IAlgebraPlugin.afterModifyPosition.selector) {
            return _afterModifyPosition(params, poolFeeCache);
        }

        if (selector == IAlgebraPlugin.beforeFlash.selector) {
            return _beforeFlash(params, poolFeeCache);
        }

        if (selector == IAlgebraPlugin.afterFlash.selector) {
            return _afterFlash(params, poolFeeCache);
        }
    }

    function _beforeSwap(
        bytes memory /* params */,
        uint16 /* poolFeeCache */
    ) internal virtual {
        revert("Not implemented");
    }

    function _afterSwap(
        bytes memory /* params */,
        uint16 /* poolFeeCache */
    ) internal virtual {
        revert("Not implemented");
    }

    function _beforeModifyPosition(
        bytes memory /* params */,
        uint16 /* poolFeeCache */
    ) internal virtual {
        revert("Not implemented");
    }

    function _afterModifyPosition(
        bytes memory /* params */,
        uint16 /* poolFeeCache */
    ) internal virtual {
        revert("Not implemented");
    }

    function _beforeFlash(
        bytes memory /* params */,
        uint16 /* poolFeeCache */
    ) internal virtual {
        revert("Not implemented");
    }

    function _afterFlash(
        bytes memory /* params */,
        uint16 /* poolFeeCache */
    ) internal virtual {
        revert("Not implemented");
    }
}
