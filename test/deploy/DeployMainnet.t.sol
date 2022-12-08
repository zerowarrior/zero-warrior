// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {DeployMainnet} from "../../script/deploy/DeployMainnet.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

import {ZeroName} from "../../src/ZeroName.sol";
import {ZeroWarrior} from "../../src/ZeroWarrior.sol";

contract DeployMainnetTest is DSTestPlus {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    DeployMainnet deployScript;

    function setUp() public {
        vm.setEnv("DEPLOYER_PRIVATE_KEY", "0x51741613d92b5d042f81a7e16ff98baf5804b6f460643531b68cec84cd64d371");
        vm.setEnv("APE_PRIVATE_KEY", "0x56ed2839d19286e5ba3cf4d4c6ec3187a63cf10504e108609e0b3a8fecb2952d");
        vm.setEnv("ZERONAME_PRIVATE_KEY", "0x9567588d07192b0b262dcb58bda813a7fc68f2aee83431dc00cd6eba4ec1e535");
        vm.setEnv("ZERO_PRIVATE_KEY", "0xa8f6861155baa1eed938e3d5be49fd269f1e42c9f83200bc98c424486dbd898b");
        vm.deal(vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY")), type(uint64).max);

        deployScript = new DeployMainnet();
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

    /// @notice Test that warrior ownership is correctly transferred to governor.
    function testWarriorOwnership() public {
        assertEq(deployScript.zeroWarrior().owner(), deployScript.governorWallet());
    }

    /// @notice Test that merkle root is set correctly.
    function testRoot() public {
        assertEq(deployScript.root(), deployScript.zeroWarrior().merkleRoot());
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

    function testWarriorClaim() public {
        ZeroWarrior warrior = deployScript.zeroWarrior();

        // Address is in the merkle root.
        address minter = 0x0fb90B14e4BF3a2e5182B9b3cBD03e8d33b5b863;

        // Merkle proof.
        bytes32[] memory proof = new bytes32[](11);
        proof[0] = 0x541a56539b694a70dde9dabe952bb520f496fce67614316102d0a842d3615f2a;
        proof[1] = 0x48b4e269c7ce862127a0acc74a4ea667571fc3d7794d3c738ba5012ab356e1bd;
        proof[2] = 0x44ede3b0062acbd441c2862a9dbfbef56939941b10f3dfd5681e352e433a40ba;
        proof[3] = 0xbbbdd1b0ab9aade132a0d46f55f9a6b9aa4cc36e40eaca0c0edde920dfd10352;
        proof[4] = 0x40696f4fa548ba37ba76376a7e1d537794ef7c76beedb45bf2e67d83b91fb35d;
        proof[5] = 0x10ecbfee943986149ef31225bd2da45c2f0d1c7aaebb6c9fb66a938e90d57995;
        proof[6] = 0x8ed4b1f65bacc0c3374030b948d54004b636896390fa8ade8e81dec61b382231;
        proof[7] = 0xcd29788189153cafa66cb771589e5211d6c0418de49b25685b5d678ed136ad1d;
        proof[8] = 0xeffb064155d13bc87b27f9f78d811053863836c89e49c6f96f3856b0144370ee;
        proof[9] = 0x7413ded58393d42ce39eaedd07d8b57f62e5c068d5608300cc7cccd96ca40380;
        proof[10] = 0xf3927c3b5a5dcce415463d504510cc3a3da57a48199a96f49e0257e2cd66d3a5;

        // Initial balance should be zero.
        assertEq(warrior.balanceOf(minter), 0);

        // Move time and mint.
        vm.warp(warrior.mintStart());
        vm.prank(minter);
        warrior.claimWarrior(proof);

        // Check that balance has increased.
        assertEq(warrior.balanceOf(minter), 1);
    }
}
