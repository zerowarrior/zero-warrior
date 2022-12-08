// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.0;

// import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
// import {Utilities} from "./utils/Utilities.sol";
// import {Vm} from "forge-std/Vm.sol";
// import {stdError} from "forge-std/Test.sol";
// import {NameNFT} from "../src/NameNFT.sol";
// import {ZeroName} from "../src/ZeroName.sol";
// import {console} from "./utils/Console.sol";

// contract NameNFTTest is DSTestPlus {
//     Vm internal immutable vm = Vm(HEVM_ADDRESS);
//     Utilities internal utils;
//     address payable[] internal users;
//     address internal mintAuth;

//     address internal user;
//     NameNFT internal nameNFT;

//     function setUp() public {
//         vm.warp(block.timestamp + 1);

//         utils = new Utilities();
//         users = utils.createUsers(5);


//         nameNFT = new NameNFT(ZeroName(address(this)), 0.1e18, "aaaaa");

//         user = users[1];
//     }

//     // function testMintFromETH() public {
//     //     vm.expectRevert(stdError.arithmeticError);
//     //     vm.prank(user);
//     //     nameNFT.mintFromETH("abababab");
//     // }

//     // function testMintFromZeroName() public {
//     //     vm.expectRevert(stdError.arithmeticError);
//     //     vm.prank(user);
//     //     nameNFT.mintFromZeroName("abababab", 1);
//     // }

//     // function testMintBeforeStart() public {
//     //     vm.warp(block.timestamp - 1);

//     //     vm.expectRevert(stdError.arithmeticError);
//     //     vm.prank(user);
//     //     zeroname.mintFromZero(type(uint256).max, false);
//     // }
// }
