// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {DeployRinkeby} from "../../script/deploy/DeployRinkeby.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

import {ZeroName} from "../../src/ZeroName.sol";
import {ZeroWarrior} from "../../src/ZeroWarrior.sol";

contract DeployRinkebyTest is DSTestPlus {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    DeployRinkeby deployScript;

    function setUp() public {
        vm.setEnv("DEPLOYER_PRIVATE_KEY", "0x51741613d92b5d042f81a7e16ff98baf5804b6f460643531b68cec84cd64d371");
        vm.setEnv("APE_PRIVATE_KEY", "0x56ed2839d19286e5ba3cf4d4c6ec3187a63cf10504e108609e0b3a8fecb2952d");
        vm.setEnv("ZERONAME_PRIVATE_KEY", "0x9567588d07192b0b262dcb58bda813a7fc68f2aee83431dc00cd6eba4ec1e535");
        vm.setEnv("ZERO_PRIVATE_KEY", "0xa8f6861155baa1eed938e3d5be49fd269f1e42c9f83200bc98c424486dbd898b");

        vm.deal(vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY")), type(uint64).max);

        deployScript = new DeployRinkeby();
        deployScript.run();
    }

    /// @notice Test zero addresses where correctly set.
    function testZeroAddressCorrectness() public {
        assertEq(deployScript.zero().zeroWarrior(), address(deployScript.zeroWarrior()));
        assertEq(address(deployScript.zero().zeroname()), address(deployScript.zeroname()));
    }

    /// @notice Test zeroname addresses where correctly set.
    function testZeroNameAddressCorrectness() public {
        assertEq(address(deployScript.zeroname().zeroWarrior()), address(deployScript.zeroWarrior()));
        assertEq(address(deployScript.zeroname().zero()), address(deployScript.zero()));
    }

    /// @notice Test that merkle root was correctly set.
    function testMerkleRoot() public {
        vm.warp(deployScript.mintStart());
        // Use merkle root as user to test simple proof.
        address user = deployScript.root();
        bytes32[] memory proof;
        ZeroWarrior warrior = deployScript.zeroWarrior();
        vm.prank(user);
        warrior.claimWarrior(proof);
        // Verify warrior ownership.
        assertEq(warrior.ownerOf(1), user);
    }

    /// @notice Test cold wallet was appropriately set.
    function testColdWallet() public {
        address coldWallet = deployScript.coldWallet();
        address communityOwner = deployScript.teamReserve().owner();
        address teamOwner = deployScript.communityReserve().owner();
        assertEq(coldWallet, communityOwner);
        assertEq(coldWallet, teamOwner);
    }

    /// @notice Test URIs are correctly set.
    function testURIs() public {
        ZeroWarrior warrior = deployScript.zeroWarrior();
        assertEq(warrior.BASE_URI(), deployScript.warriorBaseUri());
        assertEq(warrior.UNREVEALED_URI(), deployScript.warriorUnrevealedUri());
        ZeroName zeroname = deployScript.zeroname();
        assertEq(zeroname.BASE_URI(), deployScript.zeronameBaseUri());
    }
}
