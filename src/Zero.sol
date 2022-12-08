// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";


contract Zero is ERC20("Zero", "ZERO", 18) {
    address public immutable zeroWarrior;

    address public immutable zeroname;

    error Unauthorized();

    constructor(address _zeroWarrior, address _zeroname) {
        zeroWarrior = _zeroWarrior;
        zeroname = _zeroname;
    }

    modifier only(address user) {
        if (msg.sender != user) revert Unauthorized();

        _;
    }

    function mintForWarrior(address to, uint256 amount) external only(zeroWarrior) {
        _mint(to, amount);
    }

    function burnForWarrior(address from, uint256 amount) external only(zeroWarrior) {
        _burn(from, amount);
    }

    function burnForZeroName(address from, uint256 amount) external only(zeroname) {
        _burn(from, amount);
    }
}
