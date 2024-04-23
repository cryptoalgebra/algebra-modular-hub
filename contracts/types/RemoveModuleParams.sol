// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @param selector The selector of corresponding hook function
/// @param indexInHookList The index of slot in hook list to be removed from list
struct RemoveModuleParams {
    bytes4 selector;
    uint256 indexInHookList;
}
