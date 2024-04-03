// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

/*
    This structure implements compressed list of modules connected to the hook.

    One top byte used to encode additional metadata.
    Each following byte contains: 1 bit as dynamicFee flag, 1 bit as useDelegate flag, 6 bits for  global index

    | metadata | module31 | module30 | ... | module0 |
       8 bits     8 bits     8 bits          8 bits

    Each module slot contains:
    | useDynamicFee | useDelegate | global module index |
          1 bit          1 bit            6 bits
*/
type HookList is bytes32;
