// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {ZeroWarrior} from "../src/ZeroWarrior.sol";
import {RandProvider} from "../src/utils/rand/RandProvider.sol";
import {ChainlinkV1RandProvider} from "../src/utils/rand/ChainlinkV1RandProvider.sol";
import {Zero} from "../src/Zero.sol";
import {ZeroName} from "../src/ZeroName.sol";
import {LinkToken} from "./utils/mocks/LinkToken.sol";
import {VRFCoordinatorMock} from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";

contract BenchmarksTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    ZeroWarrior private warrior;
    VRFCoordinatorMock private vrfCoordinator;
    LinkToken private linkToken;
    RandProvider private randProvider;
    Zero private zero;
    ZeroName private zeroname;

    address warriorAddress;
    address zeronameAddress;

    uint256 legendaryCost;

    bytes32 private keyHash;
    uint256 private fee;

    function setUp() public {
        vm.warp(1); // Otherwise mintStart will be set to 0 and brick zeroname.mintFromZero(type(uint256).max)

        utils = new Utilities();
        users = utils.createUsers(5);
        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorMock(address(linkToken));

        // Warrior contract will be deployed after 2 contract deploys, and zeroname after 3.
        warriorAddress = utils.predictContractAddress(address(this), 2);
        zeronameAddress = utils.predictContractAddress(address(this), 3);

        randProvider = new ChainlinkV1RandProvider(
            ZeroWarrior(warriorAddress),
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            fee
        );

        zero = new Zero(warriorAddress, zeronameAddress);

        warrior = new ZeroWarrior(
            keccak256(abi.encodePacked(users[0])),
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

        vm.prank(address(warrior));
        zero.mintForWarrior(address(this), type(uint192).max);

        warrior.addZero(type(uint96).max);

        mintZeroNameToAddress(address(this), 9);
        mintWarriorToAddress(address(this), warrior.LEGENDARY_AUCTION_INTERVAL());

        vm.warp(block.timestamp + 30 days);

        legendaryCost = warrior.legendaryWarriorPrice();

        bytes32 requestId = warrior.requestRandomSeed();
        uint256 randomness = uint256(keccak256(abi.encodePacked("seed")));
        vrfCoordinator.callBackWithRandomness(requestId, randomness, address(randProvider));
    }

    function testZeroNamePrice() public view {
        zeroname.zeronamePrice();
    }

    function testWarriorPrice() public view {
        warrior.warriorPrice();
    }

    function testLegendaryWarriorPrice() public view {
        warrior.legendaryWarriorPrice();
    }

    function testZeroBalance() public view {
        warrior.zeroBalance(address(this));
    }

    function testMintZeroName() public {
        zeroname.mintFromZero(type(uint256).max, false);
    }

    function testMintZeroNameUsingVirtualBalance() public {
        zeroname.mintFromZero(type(uint256).max, true);
    }

    function testMintWarrior() public {
        warrior.mintFromZero(type(uint256).max, false);
    }

    function testMintWarriorUsingVirtualBalance() public {
        warrior.mintFromZero(type(uint256).max, true);
    }

    function testTransferWarrior() public {
        warrior.transferFrom(address(this), address(0xBEEF), 1);
    }

    function testAddZero() public {
        warrior.addZero(1e18);
    }

    function testRemoveZero() public {
        warrior.removeZero(1e18);
    }

    function testRevealWarrior() public {
        warrior.revealWarrior(100);
    }

    function testMintLegendaryWarrior() public {
        uint256 legendaryWarriorCost = legendaryCost;

        uint256[] memory ids = new uint256[](legendaryWarriorCost);
        for (uint256 i = 0; i < legendaryWarriorCost; ++i) ids[i] = i + 1;

        warrior.mintLegendaryWarrior(ids);
    }

    function testMintReservedWarrior() public {
        warrior.mintReservedWarrior(1);
    }

    function testMintCommunityZeroName() public {
        zeroname.mintCommunityZeroName(1);
    }

    function testDeployWarrior() public {
        new ZeroWarrior(
            keccak256(abi.encodePacked(users[0])),
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
    }

    function testDeployZero() public {
        new Zero(warriorAddress, zeronameAddress);
    }

    function testDeployZeroName() public {
        new ZeroName(block.timestamp, zero, address(0xBEEF), warrior, "");
    }

    function mintWarriorToAddress(address addr, uint256 num) internal {
        for (uint256 i = 0; i < num; ++i) {
            vm.startPrank(address(warrior));
            zero.mintForWarrior(addr, warrior.warriorPrice());
            vm.stopPrank();

            vm.prank(addr);
            warrior.mintFromZero(type(uint256).max, false);
        }
    }

    function mintZeroNameToAddress(address addr, uint256 num) internal {
        for (uint256 i = 0; i < num; ++i) {
            vm.startPrank(address(warrior));
            zero.mintForWarrior(addr, zeroname.zeronamePrice());
            vm.stopPrank();

            vm.prank(addr);
            zeroname.mintFromZero(type(uint256).max, false);
        }
    }
}
