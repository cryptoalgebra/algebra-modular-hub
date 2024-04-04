// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {HookList} from "../types/HookList.sol";
import {ModuleData} from "../types/ModuleData.sol";

/// @notice The Algebra modular system hub
/// @dev This contract used to proxy hook calls from the Algebra liquidity pool to different modules.
/// This way different modules can be connected to different hooks. They can be connected, replaced or removed independently at any moment.
interface IAlgebraModularHub {
    /// @notice Emitted after new module is registered
    /// @param moduleAddress The address of module contract
    /// @param moduleIndex The global index of module in ModularHub
    event ModuleRegistered(address moduleAddress, uint256 moduleIndex);

    /// @notice Emitted after module replacement
    /// @param newModuleAddress The address of new module contract
    /// @param moduleIndex The global index of module in ModularHub
    event ModuleReplaced(address newModuleAddress, uint256 moduleIndex);

    /// @notice Emitted after module added to modules list for a hook
    /// @param hookSelector The selector of corresponding hook
    /// @param moduleIndex The global index of module in ModularHub
    /// @param indexInHookList The index of module in modules list for hook
    /// @param useDelegate Should corresponding module be called with delegate call or not
    /// @param useDynamicFee Does corresponding module implement dynamic fee for this hook or not
    event ModuleAddedToHook(
        bytes4 indexed hookSelector,
        uint256 indexed moduleIndex,
        uint256 indexInHookList,
        bool useDelegate,
        bool useDynamicFee
    );

    /// @notice Emitted after module removed from modules list for a hook
    /// @param hookSelector The selector of corresponding hook
    /// @param indexInHookList The index of module in modules list for hook
    event ModuleRemovedFromHook(
        bytes4 indexed hookSelector,
        uint256 indexInHookList
    );

    /// @notice Returns the address of the pool the plugin is created for
    /// @return Address of the pool
    function pool() external view returns (address);

    /// @notice Returns the address of the AlgebraFactory
    /// @return Address of the factory
    function factory() external view returns (address);

    /// @notice Returns the role of pools administrator
    /// @return The hash corresponding to this role
    function POOLS_ADMINISTRATOR_ROLE() external view returns (bytes32);

    /// @notice Returns list of modules for the hook
    /// @param selector The selector of hook
    /// @return The list of modules for the hook
    function hookLists(bytes4 selector) external view returns (HookList);

    /// @notice Returns the module info by index
    /// @param moduleIndex The index of registered module
    /// @return The packed module info
    function modules(uint256 moduleIndex) external view returns (ModuleData);

    /// @notice Returns the amount of registered modules
    /// @return The amount of registered modules
    function modulesCounter() external view returns (uint256);

    /// @notice Returns the info about module from the hook list by index
    /// @param selector The selector of hook
    /// @param index The index in hook module list
    /// @return moduleIndex The global index of module
    /// @return implementsDynamicFee Does module implement dynamic fee or not
    /// @return useDelegate Should module be called with delegate call or not
    function getModuleForHookByIndex(
        bytes4 selector,
        uint256 index
    )
        external
        view
        returns (
            uint256 moduleIndex,
            bool implementsDynamicFee,
            bool useDelegate
        );

    /// @notice Returns the info about all modules from the hook list
    /// @param selector The selector of hook
    /// @return moduleIndexes The global indexes of modules
    /// @return hasDynamicFee Does corresponding module implement dynamic fee or not
    /// @return usesDelegate Should corresponding module be called with delegate call or not
    function getModulesForHook(
        bytes4 selector
    )
        external
        view
        returns (
            uint256[] memory moduleIndexes,
            bool[] memory hasDynamicFee,
            bool[] memory usesDelegate
        );

    /// @notice Used to register a new module globally
    /// @dev Registered modules can be accessed by short index instead of address.
    /// @dev Only pools administrator can call this.
    /// @param moduleAddress The address of module contract
    /// @return index The global index of module
    function registerModule(
        address moduleAddress
    ) external returns (uint256 index);

    /// @notice Used to replace a module globally
    /// @dev Only pools administrator can call this
    /// @param index The global index of module being replaced
    /// @param moduleAddress The address of new module contract
    function replaceModule(uint256 index, address moduleAddress) external;

    /// @notice Used to connect a module to the hook
    /// @dev Only pools administrator can call this
    /// Module will be added to the end of hook module list
    /// @param selector The selector of hook
    /// @param moduleIndex The global index of module
    /// @param useDelegate Should corresponding module be called with delegate call or not
    /// @param useDynamicFee Does corresponding module implement dynamic fee or not
    /// @return indexInHookList The index of module in hook list
    function connectModuleToHook(
        bytes4 selector,
        uint256 moduleIndex,
        bool useDelegate,
        bool useDynamicFee
    ) external returns (uint256 indexInHookList);

    /// @notice Used to insert a module to the hook modules list
    /// @dev Only pools administrator can call this
    /// @dev previous module at index will be shifted to the left
    /// @param selector The selector of hook
    /// @param indexInHookList The index of module in hook list
    /// @param moduleIndex The global index of module
    /// @param useDelegate Should corresponding module be called with delegate call or not
    /// @param useDynamicFee Does corresponding module implement dynamic fee or not
    function insertModuleToHookList(
        bytes4 selector,
        uint256 indexInHookList,
        uint256 moduleIndex,
        bool useDelegate,
        bool useDynamicFee
    ) external;

    /// @notice Used to remove a module from the hook modules list
    /// @dev Only pools administrator can call this
    /// @dev next modules be shifted to the right
    /// @param selector The selector of hook
    /// @param indexInHookList The index of module in hook list
    function removeModuleFromList(
        bytes4 selector,
        uint256 indexInHookList
    ) external;
}
