// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

/*
    This structure implements compressed data about a module.

    Currently only last 160 bits are used to store the address of module.
    Free space is reserved.

    |   free   |  address  |
       96 bits    160 bits
*/
type ModuleData is bytes32;
