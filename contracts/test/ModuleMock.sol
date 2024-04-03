// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AlgebraModule} from "../base/AlgebraModule.sol";
import {ModuleUtils} from "../libraries/ModuleUtils.sol";

contract ModuleMock is AlgebraModule {
    bool public touchedBeforeSwap;
    bool public touchedAfterSwap;

    bool public dynamicFeeBefore;
    bool public dynamicFeeAfter;

    constructor(bool _dynamicFeeBefore, bool _dynamicFeeAfter) {
        dynamicFeeBefore = _dynamicFeeBefore;
        dynamicFeeAfter = _dynamicFeeAfter;
    }

    function _beforeSwap(
        bytes memory /* params */,
        uint16 /* poolFeeCache */
    ) internal virtual override {
        touchedBeforeSwap = true;

        // To decode params for beforeSwap:
        /*
        BeforeSwapParams memory _params
            = ModuleUtils.decodeBeforeSwapParams(params);
        */

        if (dynamicFeeBefore) {
            ModuleUtils.returnDynamicFeeResult(600, false);
        }
    }

    function _afterSwap(
        bytes memory /* params */,
        uint16 /* poolFeeCache */
    ) internal virtual override {
        touchedAfterSwap = true;

        if (dynamicFeeAfter) {
            ModuleUtils.returnDynamicFeeResult(600, false);
        }
    }
}
