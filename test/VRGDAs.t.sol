// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {ZeroWarrior} from "../src/ZeroWarrior.sol";
import {Zero} from "../src/Zero.sol";
import {ZeroName} from "../src/ZeroName.sol";
import {LinkToken} from "./utils/mocks/LinkToken.sol";
import {VRFCoordinatorMock} from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";
import {RandProvider} from "../src/utils/rand/RandProvider.sol";
import {ChainlinkV1RandProvider} from "../src/utils/rand/ChainlinkV1RandProvider.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

contract VRGDAsTest is DSTestPlus {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    uint256 constant ONE_THOUSAND_YEARS = 356 days * 1000;

    Utilities internal utils;
    address payable[] internal users;

    ZeroWarrior private warrior;
    VRFCoordinatorMock private vrfCoordinator;
    LinkToken private linkToken;

    Zero zero;
    ZeroName zeroname;
    RandProvider randProvider;

    bytes32 private keyHash;
    uint256 private fee;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorMock(address(linkToken));

        address warriorAddress = utils.predictContractAddress(address(this), 2);
        address zeronameAddress = utils.predictContractAddress(address(this), 3);

        randProvider = new ChainlinkV1RandProvider(
            ZeroWarrior(warriorAddress),
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            fee
        );

        zero = new Zero(warriorAddress, zeronameAddress);

        warrior = new ZeroWarrior(
            "root",
            block.timestamp,
            zero,
            ZeroName(zeronameAddress),
            address(0xBEEF),
            address(0xBEEF),
            randProvider,
            "base",
            "",
            keccak256(abi.encodePacked("provenance"))
        );

        zeroname = new ZeroName(block.timestamp, zero, address(0xBEEF), warrior, "");
    }

    // function testFindWarriorOverflowPoint() public view {
    //     uint256 sold;
    //     while (true) {
    //         warrior.getPrice(0 days, sold++);
    //     }
    // }

    // function testFindZeroNameOverflowPoint() public view {
    //     uint256 sold;
    //     while (true) {
    //         zeroname.getPrice(0 days, sold++);
    //     }
    // 

    function testNoOverflowForMostWarrior(uint256 timeSinceStart, uint256 sold) public {
        warrior.getVRGDAPrice(
            toDaysWadUnsafe(bound(timeSinceStart, 0 days, ONE_THOUSAND_YEARS)),
            bound(sold, 0, 1730)
        );
    }

    function testNoOverflowForAllWarrior(uint256 timeSinceStart, uint256 sold) public {
        warrior.getVRGDAPrice(
            toDaysWadUnsafe(bound(timeSinceStart, 3870 days, ONE_THOUSAND_YEARS)),
            bound(sold, 0, 6391)
        );
    }

    function testFailOverflowForBeyondLimitWarrior(uint256 timeSinceStart, uint256 sold) public {
        warrior.getVRGDAPrice(
            toDaysWadUnsafe(bound(timeSinceStart, 0 days, ONE_THOUSAND_YEARS)),
            bound(sold, 6392, type(uint128).max)
        );
    }

    function testWarriorPriceStrictlyIncreasesForMostWarrior() public {
        uint256 sold;
        uint256 previousPrice;

        while (sold <= 1730) {
            uint256 price = warrior.getVRGDAPrice(0 days, sold++);
            assertGt(price, previousPrice);
            previousPrice = price;
        }
    }

    function testNoOverflowForFirst8465ZeroName(uint256 timeSinceStart, uint256 sold) public {
        zeroname.getVRGDAPrice(toDaysWadUnsafe(bound(timeSinceStart, 0 days, ONE_THOUSAND_YEARS)), bound(sold, 0, 8465));
    }

    function testZeroNamePriceStrictlyIncreasesFor8465ZeroName() public {
        uint256 sold;
        uint256 previousPrice;

        while (sold <= 8465) {
            uint256 price = zeroname.getVRGDAPrice(0 days, sold++);
            assertGt(price, previousPrice);
            previousPrice = price;
        }
    }
}
