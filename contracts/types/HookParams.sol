// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

struct BeforeInitializeParams {
    address pool;
    address sender;
    uint160 sqrtPriceX96;
    uint256 moduleGlobalIndex;
}

struct AfterInitializeParams {
    address pool;
    address sender;
    uint160 sqrtPriceX96;
    int24 tick;
}

struct BeforeSwapParams {
    address pool;
    address sender;
    address recipient;
    bool zeroToOne;
    int256 amountRequired;
    uint160 limitSqrtPrice;
    bool withPaymentInAdvance;
    bytes data;
}

struct AfterSwapParams {
    address pool;
    address sender;
    address recipient;
    bool zeroToOne;
    int256 amountRequired;
    uint160 limitSqrtPrice;
    int256 amount0;
    int256 amount1;
    bytes data;
}

struct BeforeModifyPositionParams {
    address pool;
    address sender;
    address recipient;
    int24 bottomTick;
    int24 topTick;
    int128 desiredLiquidityDelta;
    bytes data;
}

struct AfterModifyPositionParams {
    address pool;
    address sender;
    address recipient;
    int24 bottomTick;
    int24 topTick;
    int128 desiredLiquidityDelta;
    uint256 amount0;
    uint256 amount1;
    bytes data;
}

struct BeforeFlashParams {
    address pool;
    address sender;
    address recipient;
    uint256 amount0;
    uint256 amount1;
    bytes data;
}

struct AfterFlashParams {
    address pool;
    address sender;
    address recipient;
    uint256 amount0;
    uint256 amount1;
    uint256 paid0;
    uint256 paid1;
    bytes data;
}
