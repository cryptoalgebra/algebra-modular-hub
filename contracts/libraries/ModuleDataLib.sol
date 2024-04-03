// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ModuleData} from "../types/ModuleData.sol";

library ModuleDataLib {
    /// @dev Encodes data about the module
    function write(
        address moduleAddress
    ) internal pure returns (ModuleData result) {
        assembly {
            result := and(
                moduleAddress,
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            )
        }
    }

    /// @dev Returns module address from encoded ModuleData
    function getAddress(
        ModuleData data
    ) internal pure returns (address moduleAddress) {
        assembly {
            moduleAddress := and(
                data,
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            )
        }
    }
}
