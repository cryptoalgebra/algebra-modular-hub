// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AlgebraModule} from "../base/AlgebraModule.sol";
import {ModuleUtils} from "../libraries/ModuleUtils.sol";


contract ModuleMock is AlgebraModule {
    bool public touchedBeforeSwap;
    bool public touchedAfterSwap;

    bool public dynamicFeeBefore;
    bool public dynamicFeeAfter;

    bool public immediatelyUpdateDynamicFeeBefore;
    bool public immediatelyUpdateDynamicFeeAfter;

    bool public revertsSilently;
    bool public revertsWithMessage;

    constructor(address _modularHub, bool _dynamicFeeBefore, bool _dynamicFeeAfter) AlgebraModule(_modularHub) {
        dynamicFeeBefore = _dynamicFeeBefore;
        dynamicFeeAfter = _dynamicFeeAfter;
    }

    function setRevert() external {
        revertsSilently = true;
    }

    function setRevertWithMessage() external {
        revertsWithMessage = true;
    }

    function setImmediatelyUpdateDynamicFee(bool before, bool value) external {
        if (before) immediatelyUpdateDynamicFeeBefore = value;
        else immediatelyUpdateDynamicFeeAfter = value;
    }

    function _beforeSwap(
        bytes memory /* params */,
        uint16 /* poolFeeCache */
    ) internal virtual override {
        require(!revertsSilently);
        require(!revertsWithMessage, "Revert in module mock");
        touchedBeforeSwap = true;

        // To decode params for beforeSwap:
        /*
        BeforeSwapParams memory _params
            = ModuleUtils.decodeBeforeSwapParams(params);
        */

        if (dynamicFeeBefore) {
            ModuleUtils.returnDynamicFeeResult(
                600,
                immediatelyUpdateDynamicFeeBefore
            );
        }
    }

    function _afterSwap(
        bytes memory /* params */,
        uint16 /* poolFeeCache */
    ) internal virtual override {
        touchedAfterSwap = true;

        if (dynamicFeeAfter) {
            ModuleUtils.returnDynamicFeeResult(
                600,
                immediatelyUpdateDynamicFeeAfter
            );
        }
    }
}
