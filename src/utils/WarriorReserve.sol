// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";

import {ZeroWarrior} from "../ZeroWarrior.sol";

contract WarriorReserve is Owned {
    ZeroWarrior public immutable zeroWarrior;

    constructor(ZeroWarrior _zeroWarrior, address _owner) Owned(_owner) {
        zeroWarrior = _zeroWarrior;
    }

    function withdraw(address to, uint256[] calldata ids) external onlyOwner {
        unchecked {
            for (uint256 i = 0; i < ids.length; ++i) {
                zeroWarrior.transferFrom(address(this), to, ids[i]);
            }
        }
    }
}
