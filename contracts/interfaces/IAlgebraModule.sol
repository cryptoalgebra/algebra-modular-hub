// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

/// @notice The interface of a module for the Algebra Modular system.
interface IAlgebraModule {
    /// @notice Returns address of modular hub to which this plugin is connected
    /// @return Address of modular hub to which this plugin is connected
    function modularHub() external view returns (address);

    /// @notice Returns address of pool to which modular hub is connected
    /// @return Address of pool to which modular hub is connected
    function pool() external view returns (address);

    /// @notice The main entry-point of module
    /// @param selector The AlgebraPlugin hook selector
    /// @param params Abi encoded set of params
    /// @param poolFeeCache The cached value of pool fee. Will be provided only if module is registered as dynamic fee module
    function execute(
        bytes4 selector,
        bytes memory params,
        uint16 poolFeeCache
    ) external;
}
