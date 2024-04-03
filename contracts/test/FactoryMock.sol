// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract FactoryMock {
    address public owner;

    mapping(bytes32 role => mapping(address user => bool)) hasRole;

    constructor() {
        owner = msg.sender;
    }

    function hasRoleOrOwner(
        bytes32 role,
        address user
    ) external view returns (bool) {
        return user == owner || hasRole[role][user];
    }

    function setRoleStatus(bytes32 role, address user, bool value) external {
        hasRole[role][user] = value;
    }
}
