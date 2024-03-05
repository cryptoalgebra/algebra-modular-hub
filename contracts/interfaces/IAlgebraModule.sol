// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAlgebraModule {
    /**
     * @notice The main entry-point of module
     * @param selector The AlgebraPlugin hook selector
     * @param params Abi encoded set of params
     * @param poolFeeCache The cached value of pool fee. Will be provided only if module is registered as dynamic fee module
     */
    function execute(
        bytes4 selector,
        bytes memory params,
        uint16 poolFeeCache
    ) external;
}
