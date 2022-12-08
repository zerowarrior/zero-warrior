// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdError} from "forge-std/Test.sol";
import {ZeroWarrior} from "../src/ZeroWarrior.sol";
import {Zero} from "../src/Zero.sol";
import {ZeroName} from "../src/ZeroName.sol";
import {WarriorReserve} from "../src/utils/WarriorReserve.sol";
import {RandProvider} from "../src/utils/rand/RandProvider.sol";
import {ChainlinkV1RandProvider} from "../src/utils/rand/ChainlinkV1RandProvider.sol";
import {LinkToken} from "./utils/mocks/LinkToken.sol";
import {VRFCoordinatorMock} from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {LibString} from "solmate/utils/LibString.sol";

contract RandProviderTest is DSTestPlus {
    using LibString for uint256;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    ZeroWarrior internal warrior;
    VRFCoordinatorMock internal vrfCoordinator;
    LinkToken internal linkToken;
    Zero internal zero;
    ZeroName internal zeroname;
    WarriorReserve internal team;
    WarriorReserve internal community;
    RandProvider internal randProvider;

    bytes32 private keyHash;
    uint256 private fee;

    uint256[] ids;

    
    event RandomnessRequest(address indexed sender, bytes32 indexed keyHash, uint256 indexed seed);



    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorMock(address(linkToken));

        address warriorAddress = utils.predictContractAddress(address(this), 4);
        address zeronameAddress = utils.predictContractAddress(address(this), 5);

        team = new WarriorReserve(ZeroWarrior(warriorAddress), address(this));
        community = new WarriorReserve(ZeroWarrior(warriorAddress), address(this));
        randProvider = new ChainlinkV1RandProvider(
            ZeroWarrior(warriorAddress),
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            fee
        );

        zero = new Zero(
            utils.predictContractAddress(address(this), 1),
            utils.predictContractAddress(address(this), 2)
        );

        warrior = new ZeroWarrior(
            keccak256(abi.encodePacked(users[0])),
            block.timestamp,
            zero,
            ZeroName(zeronameAddress),
            address(team),
            address(community),
            randProvider,
            "base",
            "",
            keccak256(abi.encodePacked("provenance"))
        );

        zeroname = new ZeroName(block.timestamp, zero, address(0xBEEF), warrior, "");
    }

    function testRandomnessIsCorrectlyRequested() public {
        mintWarriorToAddress(users[0], 1);
        vm.warp(block.timestamp + 1 days);

        vm.expectEmit(true, false, false, false);
        emit RandomnessRequest(address(randProvider), 0, 0);

        warrior.requestRandomSeed();
    }

    function testRandomnessIsFulfilled() public {
        (uint64 randomSeed, , , , ) = warrior.warriorRevealsData();
        assertEq(randomSeed, 0);
        mintWarriorToAddress(users[0], 1);
        vm.warp(block.timestamp + 1 days);
        bytes32 requestId = warrior.requestRandomSeed();
        uint256 randomness = uint256(keccak256(abi.encodePacked("seed")));
        vrfCoordinator.callBackWithRandomness(requestId, randomness, address(randProvider));
        (randomSeed, , , , ) = warrior.warriorRevealsData();
        assertEq(randomSeed, uint64(randomness));
    }

    function testOnlyWarriorCanRequestRandomness() public {
        vm.expectRevert(ChainlinkV1RandProvider.NotWarrior.selector);
        randProvider.requestRandomBytes();
    }

    function testRandomnessIsOnlyUpgradableByOwner() public {
        RandProvider newProvider = new ChainlinkV1RandProvider(ZeroWarrior(address(0)), address(0), address(0), 0, 0);
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(address(0xBEEFBABE));
        warrior.upgradeRandProvider(newProvider);
    }

    function testRandomnessIsUpgradable() public {
        mintWarriorToAddress(users[0], 1);
        vm.warp(block.timestamp + 1 days);
        assertEq(address(warrior.randProvider()), address(randProvider));

        RandProvider newProvider = new ChainlinkV1RandProvider(ZeroWarrior(address(0)), address(0), address(0), 0, 0);
        warrior.upgradeRandProvider(newProvider);
        assertEq(address(warrior.randProvider()), address(newProvider));
    }

    function testRandomnessIsResetWithPendingSeed() public {
        mintWarriorToAddress(users[0], 1);
        vm.warp(block.timestamp + 1 days);
        warrior.requestRandomSeed();
        (, , , uint256 toBeRevealed, bool waiting) = warrior.warriorRevealsData();
        assertTrue(waiting);
        assertEq(toBeRevealed, 1);

        RandProvider newProvider = new ChainlinkV1RandProvider(
            warrior,
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            fee
        );
        warrior.upgradeRandProvider(newProvider);

        (, , , toBeRevealed, waiting) = warrior.warriorRevealsData();
        assertFalse(waiting);
        assertEq(toBeRevealed, 0);

        bytes32 requestId = warrior.requestRandomSeed();
        (, , , toBeRevealed, waiting) = warrior.warriorRevealsData();
        assertTrue(waiting);
        assertEq(toBeRevealed, 1);

        uint256 randomness = uint256(keccak256(abi.encodePacked("seed")));
        vrfCoordinator.callBackWithRandomness(requestId, randomness, address(newProvider));
        (uint256 randomSeed, , , , ) = warrior.warriorRevealsData();
        assertEq(randomSeed, uint64(randomness));
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
}
