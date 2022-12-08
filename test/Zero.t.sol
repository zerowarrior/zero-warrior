// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdError} from "forge-std/Test.sol";
import {Zero} from "../src/Zero.sol";

contract ZeroTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;
    Zero internal zero;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        zero = new Zero(address(this), users[0]);
    }

    function testMintByAuthority() public {
        uint256 initialSupply = zero.totalSupply();
        uint256 mintAmount = 100000;
        zero.mintForWarrior(address(this), mintAmount);
        uint256 finalSupply = zero.totalSupply();
        assertEq(finalSupply, initialSupply + mintAmount);
    }

    function testMintByNonAuthority() public {
        uint256 mintAmount = 100000;
        vm.prank(users[0]);
        vm.expectRevert(Zero.Unauthorized.selector);
        zero.mintForWarrior(address(this), mintAmount);
    }

    function testSetZeroName() public {
        zero.mintForWarrior(address(this), 1000000);
        uint256 initialSupply = zero.totalSupply();
        uint256 burnAmount = 100000;
        vm.prank(users[0]);
        zero.burnForZeroName(address(this), burnAmount);
        uint256 finalSupply = zero.totalSupply();
        assertEq(finalSupply, initialSupply - burnAmount);
    }

    function testBurnAllowed() public {
        uint256 mintAmount = 100000;
        zero.mintForWarrior(address(this), mintAmount);
        uint256 burnAmount = 30000;
        zero.burnForWarrior(address(this), burnAmount);
        uint256 finalBalance = zero.balanceOf(address(this));
        assertEq(finalBalance, mintAmount - burnAmount);
    }

    function testBurnNotAllowed() public {
        uint256 mintAmount = 100000;
        zero.mintForWarrior(address(this), mintAmount);
        uint256 burnAmount = 200000;
        vm.expectRevert(stdError.arithmeticError);
        zero.burnForWarrior(address(this), burnAmount);
    }
}
