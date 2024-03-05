// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAlgebraPlugin} from "@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol";
import {IAlgebraPool} from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";

import {IAlgebraModule} from "./interfaces/IAlgebraModule.sol";

import "hardhat/console.sol";

// Prototype version
contract AlgebraModularHub is IAlgebraPlugin {
    address public immutable pool;

    mapping(bytes4 hookSelector => bytes32) public hookLists;
    mapping(uint256 moduleIndex => bytes32) public modules;

    uint256 public modulesCounter;

    uint256 private constant DYNAMIC_FEE_FLAG = 1;

    modifier onlyPool() {
        require(msg.sender == pool);
        _;
    }

    constructor(address _pool) {
        pool = _pool;
    }

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
        )
    {
        // TODO check selector
        return _readModuleInfoForHook(hookLists[selector], index);
    }

    // TODO only admin
    function registerModule(address module) external {
        uint256 index = ++modulesCounter; // starting from 1

        bytes32 data;
        assembly {
            data := and(module, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
        modules[index] = data;
    }

    // TODO only admin
    function replaceModule(uint256 index, address module) external {
        //! dangerous action
        require(index <= modulesCounter);
        bytes32 data;
        assembly {
            data := and(module, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
        modules[index] = data;
    }

    // TODO only admin
    function connectModuleToHook(
        bytes4 selector,
        uint256 moduleIndex,
        bool useDelegate,
        bool useDynamicFee
    ) external {
        // TODO check selector

        require(moduleIndex <= modulesCounter && moduleIndex < 1 << 6);
        bytes32 config = hookLists[selector];

        uint256 freePlacePointer;
        for (; freePlacePointer < 32; ++freePlacePointer) {
            if (freePlacePointer == 31) revert("No free place");

            uint256 moduleInfo;
            assembly {
                moduleInfo := and(shr(mul(freePlacePointer, 8), config), 0xFF)
            }
            if (moduleInfo == 0) break;
        }

        assembly {
            let moduleInfo := or(moduleIndex, shl(6, useDelegate))
            moduleInfo := or(moduleInfo, shl(7, useDynamicFee))
            config := or(
                config,
                shl(mul(freePlacePointer, 8), and(0xFF, moduleInfo))
            )
        }

        // TODO should check if we have dynamic fee modules connected
        if (useDynamicFee) {
            uint256 metadata;
            assembly {
                metadata := shr(31, config)
            }
            if (metadata & DYNAMIC_FEE_FLAG == 0) {
                metadata = metadata | DYNAMIC_FEE_FLAG;
                // TODO use mask to clear old metadata
                assembly {
                    config := or(config, shl(31, metadata))
                }
            }
        }

        hookLists[selector] = config;
    }

    // TODO add insert module to hook list

    function defaultPluginConfig() external pure returns (uint8) {
        return 0;
    }

    /// @inheritdoc IAlgebraPlugin
    function beforeInitialize(
        address,
        uint160
    ) external view override onlyPool returns (bytes4) {
        return IAlgebraPlugin.beforeInitialize.selector;
    }

    /// @inheritdoc IAlgebraPlugin
    function afterInitialize(
        address,
        uint160,
        int24
    ) external view override onlyPool returns (bytes4 selector) {
        return IAlgebraPlugin.afterInitialize.selector;
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
            pool,
            sender,
            recipient,
            bottomTick,
            topTick,
            desiredLiquidityDelta,
            data
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
            pool,
            sender,
            recipient,
            bottomTick,
            topTick,
            desiredLiquidityDelta,
            amount0,
            amount1,
            data
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
            pool,
            sender,
            recipient,
            zeroToOne,
            amountRequired,
            limitSqrtPrice,
            withPaymentInAdvance,
            data
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
            pool,
            sender,
            recipient,
            zeroToOne,
            amountRequired,
            limitSqrtPrice,
            amount0,
            amount1,
            data
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
            pool,
            sender,
            recipient,
            amount0,
            amount1,
            data
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
            pool,
            sender,
            recipient,
            amount0,
            amount1,
            paid0,
            paid1,
            data
        );
        _executeHook(selector, params);
    }

    function _executeHook(bytes4 selector, bytes memory params) internal {
        bytes32 config = hookLists[selector];
        uint16 poolFee;
        uint16 poolFeeCache;
        {
            // read metadata from highest byte
            uint256 metadata;
            assembly {
                metadata := shr(31, config)
            }
            if (metadata & DYNAMIC_FEE_FLAG != 0) {
                poolFee = _getCurrentFee(pool);
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
                ) = _readModuleInfoForHook(config, i);
                if (index == 0) break;

                // we are trying to minimize cold slots SLOADs
                bytes32 module = modules[index];
                address moduleAddress;
                assembly {
                    moduleAddress := and(
                        module,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
                    )
                }

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

                if (!success) {
                    // Look for revert reason and bubble it up if present
                    require(returnData.length > 0);
                    // The easiest way to bubble the revert reason is using memory via assembly
                    assembly ("memory-safe") {
                        revert(add(32, returnData), mload(returnData))
                    }
                }

                if (implementsDynamicFee) {
                    // in this case module should return fee value and updateFeeImmediately
                    bool updateImmediately;
                    (poolFeeCache, updateImmediately) = _decodeDynamicFeeResult(
                        returnData
                    );

                    if (updateImmediately) {
                        poolFee = poolFeeCache;
                        _updateFeeInPool(pool, poolFeeCache);
                    }
                }
            }
        }

        if (poolFee != poolFeeCache) {
            _updateFeeInPool(pool, poolFeeCache);
        }
    }

    function _decodeDynamicFeeResult(
        bytes memory returnData
    ) internal pure returns (uint16 feeValue, bool updateFeeImmediately) {
        assembly {
            feeValue := mload(add(0x20, returnData))
            updateFeeImmediately := mload(add(0x40, returnData))
        }
        return (feeValue, updateFeeImmediately);
    }

    function _readModuleInfoForHook(
        bytes32 hookList,
        uint256 index
    )
        internal
        pure
        returns (
            uint256 moduleIndex,
            bool implementsDynamicFee,
            bool useDelegate
        )
    {
        // each byte contains: 6 bits for index, 1 bit as dynamicFee flag, 1 bit as useDelegate flag
        // so we can have only 64 module total
        assembly {
            moduleIndex := shr(mul(index, 8), hookList)
            implementsDynamicFee := and(shr(7, moduleIndex), 1)
            useDelegate := and(shr(6, moduleIndex), 1)
            moduleIndex := and(0x3F, moduleIndex)
        }
    }

    function _updateFeeInPool(address poolAddress, uint16 value) internal {
        IAlgebraPool(poolAddress).setFee(value);
    }

    function _getCurrentFee(
        address poolAddress
    ) internal view returns (uint16) {
        (, , uint16 lastFee, , , ) = IAlgebraPool(poolAddress).globalState();
        return lastFee;
    }
}
