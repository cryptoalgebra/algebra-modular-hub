// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BeforeSwapParams, AfterSwapParams, BeforeModifyPositionParams, AfterModifyPositionParams, BeforeFlashParams, AfterFlashParams} from "../types/HookParams.sol";

library ModuleUtils {
    /// @dev Used to immediately return dynamic fee data from module to the Modular Hub
    function returnDynamicFeeResult(
        uint16 newFeeValue,
        bool updateImmediately
    ) internal pure {
        bytes memory returnData = abi.encode(newFeeValue, updateImmediately);
        assembly {
            return(add(0x20, returnData), mload(returnData))
        }
    }

    // Helper functions used to simplify decoding of params in modules

    function decodeBeforeSwapParams(
        bytes memory params
    ) internal pure returns (BeforeSwapParams memory result) {
        result = abi.decode(params, (BeforeSwapParams));
    }

    function decodeAfterSwapParams(
        bytes memory params
    ) internal pure returns (AfterSwapParams memory result) {
        result = abi.decode(params, (AfterSwapParams));
    }

    function decodeBeforeModifyPositionParams(
        bytes memory params
    ) internal pure returns (BeforeModifyPositionParams memory result) {
        result = abi.decode(params, (BeforeModifyPositionParams));
    }

    function decodeAfterModifyPositionParams(
        bytes memory params
    ) internal pure returns (AfterModifyPositionParams memory result) {
        result = abi.decode(params, (AfterModifyPositionParams));
    }

    function decodeBeforeFlashParams(
        bytes memory params
    ) internal pure returns (BeforeFlashParams memory result) {
        result = abi.decode(params, (BeforeFlashParams));
    }

    function decodeAfterFlashParams(
        bytes memory params
    ) internal pure returns (AfterFlashParams memory result) {
        result = abi.decode(params, (AfterFlashParams));
    }
}
