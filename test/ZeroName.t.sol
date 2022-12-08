// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {Utilities} from "./utils/Utilities.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdError} from "forge-std/Test.sol";
import {Zero} from "../src/Zero.sol";
import {ZeroName} from "../src/ZeroName.sol";
import {ZeroWarrior} from "../src/ZeroWarrior.sol";
import {console} from "./utils/Console.sol";
import {fromDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

contract ZeroNameTest is DSTestPlus {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;
    address internal mintAuth;

    address internal user;
    Zero internal zero;
    ZeroName internal zeroname;
    uint256 mintStart;

    address internal community = address(0xBEEF);

    function setUp() public {
        vm.warp(block.timestamp + 1);

        utils = new Utilities();
        users = utils.createUsers(5);

        zero = new Zero(
            address(this),
            utils.predictContractAddress(address(this), 1)
        );

        zeroname = new ZeroName(block.timestamp, zero, community, ZeroWarrior(address(this)), "");

        user = users[1];
    }

    function testMintBeforeSetMint() public {
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(user);
        zeroname.mintFromZero(type(uint256).max, false);
    }

    function testMintBeforeStart() public {
        vm.warp(block.timestamp - 1);

        vm.expectRevert(stdError.arithmeticError);
        vm.prank(user);
        zeroname.mintFromZero(type(uint256).max, false);
    }

    function testRegularMint() public {
        zero.mintForWarrior(user, zeroname.zeronamePrice());
        vm.prank(user);
        zeroname.mintFromZero(type(uint256).max, false);
        assertEq(user, zeroname.ownerOf(1));
    }

    function testTargetPrice() public {
        vm.warp(block.timestamp + fromDaysWadUnsafe(zeroname.getTargetSaleTime(1e18)));

        uint256 cost = zeroname.zeronamePrice();
        assertRelApproxEq(cost, uint256(zeroname.targetPrice()), 0.00001e18);
    }

    function testMintCommunityZeroNameFailsWithNoMints() public {
        vm.expectRevert(ZeroName.ReserveImbalance.selector);
        zeroname.mintCommunityZeroName(1);
    }

    function testCanMintCommunity() public {
        mintZeroNameToAddress(user, 9);

        zeroname.mintCommunityZeroName(1);
        assertEq(zeroname.ownerOf(10), address(community));
    }

    function testCanMintMultipleCommunity() public {
        mintZeroNameToAddress(user, 90);

        zeroname.mintCommunityZeroName(10);
        assertEq(zeroname.ownerOf(91), address(community));
        assertEq(zeroname.ownerOf(92), address(community));
        assertEq(zeroname.ownerOf(93), address(community));
        assertEq(zeroname.ownerOf(94), address(community));
        assertEq(zeroname.ownerOf(95), address(community));
        assertEq(zeroname.ownerOf(96), address(community));
        assertEq(zeroname.ownerOf(97), address(community));
        assertEq(zeroname.ownerOf(98), address(community));
        assertEq(zeroname.ownerOf(99), address(community));
        assertEq(zeroname.ownerOf(100), address(community));

        assertEq(zeroname.numMintedForCommunity(), 10);
        assertEq(zeroname.currentId(), 100);

        mintZeroNameToAddress(user, 1);
        assertEq(zeroname.ownerOf(101), user);
        assertEq(zeroname.currentId(), 101);
    }

    function testCantMintTooFastCommunity() public {
        mintZeroNameToAddress(user, 18);

        vm.expectRevert(ZeroName.ReserveImbalance.selector);
        zeroname.mintCommunityZeroName(3);
    }

    function testCantMintTooFastCommunityOneByOne() public {
        mintZeroNameToAddress(user, 90);

        zeroname.mintCommunityZeroName(1);
        zeroname.mintCommunityZeroName(1);
        zeroname.mintCommunityZeroName(1);
        zeroname.mintCommunityZeroName(1);
        zeroname.mintCommunityZeroName(1);
        zeroname.mintCommunityZeroName(1);
        zeroname.mintCommunityZeroName(1);
        zeroname.mintCommunityZeroName(1);
        zeroname.mintCommunityZeroName(1);
        zeroname.mintCommunityZeroName(1);

        vm.expectRevert(ZeroName.ReserveImbalance.selector);
        zeroname.mintCommunityZeroName(1);
    }

    function testSwitchSmoothness() public {
        uint256 switchZeroNameSaleTime = uint256(zeroname.getTargetSaleTime(8337e18) - zeroname.getTargetSaleTime(8336e18));

        assertRelApproxEq(
            uint256(zeroname.getTargetSaleTime(8336e18) - zeroname.getTargetSaleTime(8335e18)),
            switchZeroNameSaleTime,
            0.0005e18
        );

        assertRelApproxEq(
            switchZeroNameSaleTime,
            uint256(zeroname.getTargetSaleTime(8338e18) - zeroname.getTargetSaleTime(8337e18)),
            0.005e18
        );
    }

    function testZeroNamePricingPricingBeforeSwitch() public {
        uint256 timeDelta = 60 days;
        uint256 numMint = 3572;

        vm.warp(block.timestamp + timeDelta);

        uint256 targetPrice = uint256(zeroname.targetPrice());

        for (uint256 i = 0; i < numMint; ++i) {
            uint256 price = zeroname.zeronamePrice();
            zero.mintForWarrior(user, price);
            vm.prank(user);
            zeroname.mintFromZero(price, false);
        }

        uint256 finalPrice = zeroname.zeronamePrice();

        assertRelApproxEq(targetPrice, finalPrice, 0.01e18);
    }

    function testZeroNamePricingPricingAfterSwitch() public {
        uint256 timeDelta = 360 days;
        uint256 numMint = 9479;

        vm.warp(block.timestamp + timeDelta);

        uint256 targetPrice = uint256(zeroname.targetPrice());

        for (uint256 i = 0; i < numMint; ++i) {
            uint256 price = zeroname.zeronamePrice();
            zero.mintForWarrior(user, price);
            vm.prank(user);
            zeroname.mintFromZero(price, false);
        }

        uint256 finalPrice = zeroname.zeronamePrice();

        assertRelApproxEq(finalPrice, targetPrice, 0.02e18);
    }

    function testInsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert(stdError.arithmeticError);
        zeroname.mintFromZero(type(uint256).max, false);
    }

    function testMintPriceExceededMax() public {
        uint256 cost = zeroname.zeronamePrice();
        zero.mintForWarrior(user, cost);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ZeroName.PriceExceededMax.selector, cost));
        zeroname.mintFromZero(cost - 1, false);
    }

    function mintZeroNameToAddress(address addr, uint256 num) internal {
        for (uint256 i = 0; i < num; ++i) {
            zero.mintForWarrior(addr, zeroname.zeronamePrice());

            vm.prank(addr);
            zeroname.mintFromZero(type(uint256).max, false);
        }
    }
}
