// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAlgebraPlugin} from "@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol";

contract PoolMock {
    uint160 public currentPrice = uint160(1) * (2 ** 96);
    uint16 public currentFee = 500;
    address public plugin;
    uint8 public _pluginConfig;

    function globalState()
        external
        view
        returns (
            uint160 price,
            int24,
            uint16 lastFee,
            uint8 pluginConfig,
            uint16,
            bool
        )
    {
        return (currentPrice, 0, currentFee, _pluginConfig, 0, true);
    }

    function setPrice(uint160 newValue) external {
        currentPrice = newValue;
    }

    function setFee(uint16 feeValue) external {
        currentFee = feeValue;
    }

    function setPlugin(address _plugin) external {
        plugin = _plugin;
    }

    function setPluginConfig(uint8 newPluginConfig) external {
        _pluginConfig = newPluginConfig;
    }

    function pseudoSwap(uint160 toPrice) external {
        uint160 _price = currentPrice;
        bool zto = toPrice <= _price;

        IAlgebraPlugin(plugin).beforeSwap(
            msg.sender,
            msg.sender,
            zto,
            1000000000,
            0,
            false,
            ""
        );

        currentPrice = toPrice;

        IAlgebraPlugin(plugin).afterSwap(
            msg.sender,
            msg.sender,
            zto,
            1000000000,
            0,
            -1000000000,
            1000000000,
            ""
        );
    }

    function callBeforeSwap() external {
        IAlgebraPlugin(plugin).beforeSwap(
            msg.sender,
            msg.sender,
            true,
            1000000000,
            0,
            false,
            ""
        );
    }

    function callAfterSwap() external {
        IAlgebraPlugin(plugin).afterSwap(
            msg.sender,
            msg.sender,
            true,
            1000000000,
            0,
            -1000000000,
            1000000000,
            ""
        );
    }
}
