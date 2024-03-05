// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AlgebraModule} from "../base/AlgebraModule.sol";

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
        bytes memory params,
        uint16 /* poolFeeCache */
    ) internal virtual override {
        touchedBeforeSwap = true;

        // To decode params for beforeSwap:
        /*
        (
            address pool, // additional value
            address sender,
            address recipient,
            bool zeroToOne,
            int256 amountRequired,
            uint160 limitSqrtPrice,
            bool withPaymentInAdvance,
            bytes memory data
        ) = abi.decode(
                params,
                (address, address, address, bool, int256, uint160, bool, bytes)
            );
        */

        if (dynamicFeeBefore) {
            _returnDynamicFeeResult(600, false);
        }
    }

    function _afterSwap(
        bytes memory /* params */,
        uint16 /* poolFeeCache */
    ) internal virtual override {
        touchedAfterSwap = true;

        if (dynamicFeeAfter) {
            _returnDynamicFeeResult(600, false);
        }
    }
}
