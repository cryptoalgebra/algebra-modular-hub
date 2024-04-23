// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @param selector The selector of corresponding hook function
/// @param indexInHookList The index of slot in hook list to insert new module
/// @param moduleGlobalIndex The global index of module
/// @param useDelegate Use delegate call or not during the execution
/// @param useDynamicFee Does module implement dynamic fee logic or not
struct InsertModuleParams {
    bytes4 selector;
    uint256 indexInHookList;
    uint256 moduleGlobalIndex;
    bool useDelegate;
    bool useDynamicFee;
}
