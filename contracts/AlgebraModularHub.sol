// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAlgebraPlugin} from "@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol";
import {IAlgebraDynamicFeePlugin} from "@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraDynamicFeePlugin.sol";
import {IAlgebraPool} from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";
import {IAlgebraFactory} from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol";

import {IAlgebraModule} from "./interfaces/IAlgebraModule.sol";
import {IAlgebraModularHub} from "./interfaces/IAlgebraModularHub.sol";

import {InsertModuleParams} from "./types/InsertModuleParams.sol";
import {RemoveModuleParams} from "./types/RemoveModuleParams.sol";
import {HookList} from "./types/HookList.sol";
import {ModuleData} from "./types/ModuleData.sol";

import {HookListLib} from "./libraries/HookListLib.sol";
import {ModuleDataLib} from "./libraries/ModuleDataLib.sol";
import {PoolInteractions} from "./libraries/PoolInteractions.sol";
import {BeforeInitializeParams, AfterInitializeParams, BeforeSwapParams, AfterSwapParams, BeforeModifyPositionParams, AfterModifyPositionParams, BeforeFlashParams, AfterFlashParams} from "./types/HookParams.sol";

/// @title Algebra Modular Hub
/// @notice This plugin is used to flexibly connect different modules to the liquidity pool
/// @dev Version: Algebra Integral 1.0
contract AlgebraModularHub is
    IAlgebraPlugin,
    IAlgebraDynamicFeePlugin,
    IAlgebraModularHub
{
    using HookListLib for HookList;
    using ModuleDataLib for ModuleData;

    /// @inheritdoc IAlgebraModularHub
    address public immutable override pool;
    /// @inheritdoc IAlgebraModularHub
    address public immutable override factory;

    /// @inheritdoc IAlgebraModularHub
    bytes32 public constant override POOLS_ADMINISTRATOR_ROLE =
        keccak256("POOLS_ADMINISTRATOR"); // it`s here for the public visibility of the value

    /// @inheritdoc IAlgebraModularHub
    mapping(bytes4 hookSelector => HookList) public override hookLists;
    /// @inheritdoc IAlgebraModularHub
    mapping(uint256 moduleGlobalIndex => ModuleData) public override modules;
    /// @inheritdoc IAlgebraModularHub
    mapping(address moduleAddress => uint256 moduleGlobalIndex)
        public
        override moduleAddressToIndex;

    /// @inheritdoc IAlgebraModularHub
    uint256 public modulesCounter;

    modifier onlyPool() {
        require(msg.sender == pool, "Only pool");
        _;
    }

    modifier onlyPoolAdministrator() {
        require(
            IAlgebraFactory(factory).hasRoleOrOwner(
                POOLS_ADMINISTRATOR_ROLE,
                msg.sender
            ),
            "Only pools administrator"
        );
        _;
    }

    constructor(address _pool, address _factory) {
        pool = _pool;
        factory = _factory;
    }

    /// @inheritdoc IAlgebraModularHub
    function getModuleForHookByIndex(
        bytes4 selector,
        uint256 index
    )
        external
        view
        override
        returns (
            uint256 moduleGlobalIndex,
            bool implementsDynamicFee,
            bool useDelegate
        )
    {
        _checkSelector(selector);
        return hookLists[selector].getModule(index);
    }

    /// @inheritdoc IAlgebraModularHub
    function getModulesForHook(
        bytes4 selector
    )
        external
        view
        override
        returns (
            uint256[] memory moduleGlobalIndexes,
            bool[] memory hasDynamicFee,
            bool[] memory usesDelegate
        )
    {
        moduleGlobalIndexes = new uint256[](30);
        hasDynamicFee = new bool[](30);
        usesDelegate = new bool[](30);

        _checkSelector(selector);
        HookList config = hookLists[selector];

        uint256 length;
        for (uint256 i; i < 31; i++) {
            (moduleGlobalIndexes[i], hasDynamicFee[i], usesDelegate[i]) = config
                .getModule(i);
            if (moduleGlobalIndexes[i] == 0) break; // empty place
            length++;
        }

        // rewrite length in arrays
        assembly {
            mstore(moduleGlobalIndexes, length)
            mstore(hasDynamicFee, length)
            mstore(usesDelegate, length)
        }
    }

    /// @inheritdoc IAlgebraModularHub
    function registerModule(
        address moduleAddress
    ) external override onlyPoolAdministrator returns (uint256 index) {
        index = ++modulesCounter; // starting from 1
        require(index < 1 << 6, "Can't add new modules anymore");
        require(moduleAddressToIndex[moduleAddress] == 0, "Already registered");

        modules[index] = ModuleDataLib.write(moduleAddress);
        moduleAddressToIndex[moduleAddress] = index;
        emit ModuleRegistered(moduleAddress, index);
    }

    /// @inheritdoc IAlgebraModularHub
    function replaceModule(
        uint256 index,
        address moduleAddress
    ) external override onlyPoolAdministrator {
        // dangerous action
        require(index != 0, "Invalid index");
        require(index <= modulesCounter, "Module not registered");
        require(moduleAddress != address(0), "Can't replace module with zero");
        require(moduleAddressToIndex[moduleAddress] == 0, "Already registered");

        moduleAddressToIndex[moduleAddress] = index;
        moduleAddressToIndex[modules[index].getAddress()] = 0;
        modules[index] = ModuleDataLib.write(moduleAddress);
        emit ModuleReplaced(moduleAddress, index);
    }

    /// @inheritdoc IAlgebraModularHub
    function insertModulesToHookLists(
        InsertModuleParams[] calldata modulesParams
    ) external override onlyPoolAdministrator {
        for (uint256 i; i < modulesParams.length; i++) {
            _insertModuleToHookList(
                modulesParams[i].selector,
                modulesParams[i].indexInHookList,
                modulesParams[i].moduleGlobalIndex,
                modulesParams[i].useDelegate,
                modulesParams[i].useDynamicFee
            );
        }
    }

    function _insertModuleToHookList(
        bytes4 selector,
        uint256 indexInHookList,
        uint256 moduleGlobalIndex,
        bool useDelegate,
        bool useDynamicFee
    ) internal {
        _checkSelector(selector);
        HookList config = hookLists[selector];

        if (
            !config.hasActiveModules() &&
            selector != IAlgebraPlugin.beforeInitialize.selector
        ) {
            PoolInteractions.activateHook(pool, selector);
        }

        require(
            moduleGlobalIndex != 0 &&
                moduleGlobalIndex <= modulesCounter &&
                moduleGlobalIndex < 1 << 6,
            "Invalid module index"
        );
        require(
            modules[moduleGlobalIndex].getAddress() != address(0),
            "Module not registered"
        );
        require(indexInHookList <= 30, "Invalid index in list");

        hookLists[selector] = config.insertModule(
            indexInHookList,
            moduleGlobalIndex,
            useDelegate,
            useDynamicFee
        );

        emit ModuleAddedToHook(
            selector,
            moduleGlobalIndex,
            indexInHookList,
            useDelegate,
            useDynamicFee
        );
    }

    /// @inheritdoc IAlgebraModularHub
    function removeModulesFromHookLists(
        RemoveModuleParams[] calldata modulesParams
    ) external override onlyPoolAdministrator {
        for (uint256 i; i < modulesParams.length; i++) {
            bytes4 selector = modulesParams[i].selector;
            uint256 indexInHookList = modulesParams[i].indexInHookList;

            _checkSelector(selector);
            HookList config = hookLists[selector].removeModule(indexInHookList);

            if (
                !config.hasActiveModules() &&
                selector != IAlgebraPlugin.beforeInitialize.selector
            ) {
                PoolInteractions.deactivateHook(pool, selector);
            }
            hookLists[selector] = config;

            emit ModuleRemovedFromHook(selector, indexInHookList);
        }
    }

    /// @inheritdoc IAlgebraPlugin
    function defaultPluginConfig() external pure override returns (uint8) {
        return 0;
    }

    /// @inheritdoc IAlgebraDynamicFeePlugin
    function getCurrentFee() external pure override returns (uint16) {
        revert("getCurrentFee: not implemented");
    }

    /// @inheritdoc IAlgebraPlugin
    function beforeInitialize(
        address sender,
        uint160 sqrtPriceX96
    ) external override onlyPool returns (bytes4 selector) {
        selector = IAlgebraPlugin.beforeInitialize.selector;
        bytes memory params = abi.encode(
            BeforeInitializeParams(pool, sender, sqrtPriceX96)
        );
        _executeHook(selector, params);
    }

    /// @inheritdoc IAlgebraPlugin
    function afterInitialize(
        address sender,
        uint160 sqrtPriceX96,
        int24 tick
    ) external override onlyPool returns (bytes4 selector) {
        selector = IAlgebraPlugin.afterInitialize.selector;
        bytes memory params = abi.encode(
            AfterInitializeParams(pool, sender, sqrtPriceX96, tick)
        );
        _executeHook(selector, params);
    }

    /// @inheritdoc IAlgebraPlugin
    function beforeModifyPosition(
        address sender,
        address recipient,
        int24 bottomTick,
        int24 topTick,
        int128 desiredLiquidityDelta,
        bytes calldata data
    ) external virtual onlyPool returns (bytes4 selector) {
        selector = IAlgebraPlugin.beforeModifyPosition.selector;
        bytes memory params = abi.encode(
            BeforeModifyPositionParams(
                pool,
                sender,
                recipient,
                bottomTick,
                topTick,
                desiredLiquidityDelta,
                data
            )
        );
        _executeHook(selector, params);
    }

    /// @inheritdoc IAlgebraPlugin
    function afterModifyPosition(
        address sender,
        address recipient,
        int24 bottomTick,
        int24 topTick,
        int128 desiredLiquidityDelta,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external virtual onlyPool returns (bytes4 selector) {
        selector = IAlgebraPlugin.afterModifyPosition.selector;
        bytes memory params = abi.encode(
            AfterModifyPositionParams(
                pool,
                sender,
                recipient,
                bottomTick,
                topTick,
                desiredLiquidityDelta,
                amount0,
                amount1,
                data
            )
        );
        _executeHook(selector, params);
    }

    /// @inheritdoc IAlgebraPlugin
    function beforeSwap(
        address sender,
        address recipient,
        bool zeroToOne,
        int256 amountRequired,
        uint160 limitSqrtPrice,
        bool withPaymentInAdvance,
        bytes calldata data
    ) external virtual onlyPool returns (bytes4 selector) {
        selector = IAlgebraPlugin.beforeSwap.selector;
        bytes memory params = abi.encode(
            BeforeSwapParams(
                pool,
                sender,
                recipient,
                zeroToOne,
                amountRequired,
                limitSqrtPrice,
                withPaymentInAdvance,
                data
            )
        );
        _executeHook(selector, params);
    }

    /// @inheritdoc IAlgebraPlugin
    function afterSwap(
        address sender,
        address recipient,
        bool zeroToOne,
        int256 amountRequired,
        uint160 limitSqrtPrice,
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) external virtual onlyPool returns (bytes4 selector) {
        selector = IAlgebraPlugin.afterSwap.selector;
        bytes memory params = abi.encode(
            AfterSwapParams(
                pool,
                sender,
                recipient,
                zeroToOne,
                amountRequired,
                limitSqrtPrice,
                amount0,
                amount1,
                data
            )
        );
        _executeHook(selector, params);
    }

    /// @inheritdoc IAlgebraPlugin
    function beforeFlash(
        address sender,
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external virtual onlyPool returns (bytes4 selector) {
        selector = IAlgebraPlugin.beforeFlash.selector;
        bytes memory params = abi.encode(
            BeforeFlashParams(pool, sender, recipient, amount0, amount1, data)
        );
        _executeHook(selector, params);
    }

    /// @inheritdoc IAlgebraPlugin
    function afterFlash(
        address sender,
        address recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1,
        bytes calldata data
    ) external virtual onlyPool returns (bytes4 selector) {
        selector = IAlgebraPlugin.afterFlash.selector;
        bytes memory params = abi.encode(
            AfterFlashParams(
                pool,
                sender,
                recipient,
                amount0,
                amount1,
                paid0,
                paid1,
                data
            )
        );
        _executeHook(selector, params);
    }

    /// @dev Calls modules from the list for the hook.
    /// Params are abi encoded and passed to modules
    function _executeHook(bytes4 selector, bytes memory params) internal {
        HookList config = hookLists[selector];
        uint16 poolFee;
        uint16 poolFeeCache;
        {
            if (config.hasDynamicFee()) {
                // get and cache fee
                poolFee = PoolInteractions.getFee(pool);
                poolFeeCache = poolFee;
            }
        }

        unchecked {
            // highest byte is used for metadata
            // so we can have only 31 modules at most for each hook
            for (uint256 i; i < 31; ++i) {
                (
                    uint256 index,
                    bool implementsDynamicFee,
                    bool useDelegate
                ) = config.getModule(i);
                if (index == 0) break; // empty slot

                // we are trying to minimize cold slots SLOADs
                address moduleAddress = modules[index].getAddress();

                bool success;
                bytes memory returnData;

                if (useDelegate) {
                    (success, returnData) = moduleAddress.delegatecall(
                        abi.encodeWithSelector(
                            IAlgebraModule.execute.selector,
                            selector,
                            params,
                            poolFeeCache
                        )
                    );
                } else {
                    (success, returnData) = moduleAddress.call(
                        abi.encodeWithSelector(
                            IAlgebraModule.execute.selector,
                            selector,
                            params,
                            poolFeeCache
                        )
                    );
                }

                if (!success) _propagateError(returnData);

                if (implementsDynamicFee) {
                    // in this case module should return fee value and updateFeeImmediately
                    bool updateImmediately;
                    (poolFeeCache, updateImmediately) = _decodeDynamicFeeResult(
                        returnData
                    );

                    if (updateImmediately) {
                        if (poolFee != poolFeeCache) {
                            poolFee = poolFeeCache;
                            PoolInteractions.setFee(pool, poolFeeCache);
                        }
                    }
                }
            }
        }

        if (poolFee != poolFeeCache) {
            PoolInteractions.setFee(pool, poolFeeCache);
        }
    }

    /// @dev Checks if selector is allowed
    function _checkSelector(bytes4 selector) internal pure {
        bool correct = PoolInteractions.flagForHook(selector) != 0;
        require(correct, "Invalid selector");
    }

    /// @dev Propagates an error from external call or delegate call
    function _propagateError(bytes memory returnData) internal pure {
        // Look for revert reason and bubble it up if present
        require(returnData.length > 0); // revert silently if call reverted without any message
        // The easiest way to bubble the revert reason is using memory via assembly
        assembly ("memory-safe") {
            revert(add(32, returnData), mload(returnData))
        }
    }

    /// @dev Decodes optional dynamic fee data from call
    function _decodeDynamicFeeResult(
        bytes memory returnData
    ) internal pure returns (uint16 feeValue, bool updateFeeImmediately) {
        assembly {
            feeValue := mload(add(0x20, returnData))
            updateFeeImmediately := mload(add(0x40, returnData))
        }
        return (feeValue, updateFeeImmediately);
    }
}
