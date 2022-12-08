// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdError} from "forge-std/Test.sol";
import {ZeroWarrior, FixedPointMathLib} from "../src/ZeroWarrior.sol";
import {Zero} from "../src/Zero.sol";
import {ZeroName} from "../src/ZeroName.sol";
import {WarriorReserve} from "../src/utils/WarriorReserve.sol";
import {RandProvider} from "../src/utils/rand/RandProvider.sol";
import {ChainlinkV1RandProvider} from "../src/utils/rand/ChainlinkV1RandProvider.sol";
import {LinkToken} from "./utils/mocks/LinkToken.sol";
import {VRFCoordinatorMock} from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {MockERC1155} from "solmate/test/utils/mocks/MockERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {fromDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

contract ZeroWarriorTest is DSTestPlus {
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

    function testMintFromMintlistBeforeMintingStarts() public {
        vm.warp(block.timestamp - 1);

        address user = users[0];
        bytes32[] memory proof;
        vm.prank(user);
        vm.expectRevert(ZeroWarrior.MintStartPending.selector);
        warrior.claimWarrior(proof);
    }

    function testMintFromMintlist() public {
        address user = users[0];
        bytes32[] memory proof;
        vm.prank(user);
        warrior.claimWarrior(proof);
        assertEq(warrior.ownerOf(1), user);
        assertEq(warrior.balanceOf(user), 1);
    }

    function testMintingFromMintlistTwiceFails() public {
        address user = users[0];
        bytes32[] memory proof;
        vm.startPrank(user);
        warrior.claimWarrior(proof);

        vm.expectRevert(ZeroWarrior.AlreadyClaimed.selector);
        warrior.claimWarrior(proof);
    }

    function testMintNotInMintlist() public {
        bytes32[] memory proof;
        vm.expectRevert(ZeroWarrior.InvalidProof.selector);
        warrior.claimWarrior(proof);
    }

    function testMintFromZero() public {
        uint256 cost = warrior.warriorPrice();
        vm.prank(address(warrior));
        zero.mintForWarrior(users[0], cost);
        vm.prank(users[0]);
        warrior.mintFromZero(type(uint256).max, false);
        assertEq(warrior.ownerOf(1), users[0]);
    }

    function testMintInsufficientBalance() public {
        vm.prank(users[0]);
        vm.expectRevert(stdError.arithmeticError);
        warrior.mintFromZero(type(uint256).max, false);
    }

    function testMintFromZeroBalance() public {
        uint256 cost = warrior.warriorPrice();
        vm.prank(address(warrior));
        zero.mintForWarrior(users[0], cost);
        vm.prank(users[0]);
        warrior.mintFromZero(type(uint256).max, false);
        assertEq(warrior.balanceOf(users[0]), 1);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");
        vm.warp(block.timestamp + 3 days);
        uint256 initialBalance = warrior.zeroBalance(users[0]);
        uint256 warriorPrice = warrior.warriorPrice();
        assertTrue(initialBalance > warriorPrice);
        console.log("newPrice", warriorPrice);
        console.log("balance", initialBalance);
        vm.prank(users[0]);
        warrior.mintFromZero(type(uint256).max, true);
        assertEq(warrior.ownerOf(2), users[0]);
        uint256 finalBalance = warrior.zeroBalance(users[0]);
        uint256 paidZero = initialBalance - finalBalance;
        assertEq(paidZero, warriorPrice);
    }

    function testMintFromBalanceInsufficient() public {
        vm.prank(users[0]);
        vm.expectRevert(stdError.arithmeticError);
        warrior.mintFromZero(type(uint256).max, true);
    }

    function testMintPriceExceededMax() public {
        uint256 cost = warrior.warriorPrice();
        vm.prank(address(warrior));
        zero.mintForWarrior(users[0], cost);
        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(ZeroWarrior.PriceExceededMax.selector, cost));
        warrior.mintFromZero(cost - 1, false);
    }

    function testInitialWarriorPrice() public {
        vm.warp(block.timestamp + fromDaysWadUnsafe(warrior.getTargetSaleTime(1e18)));

        uint256 cost = warrior.warriorPrice();
        assertRelApproxEq(cost, uint256(warrior.targetPrice()), 0.00001e18);
    }

    function testMintReservedWarriorFailsWithNoMints() public {
        vm.expectRevert(ZeroWarrior.ReserveImbalance.selector);
        warrior.mintReservedWarrior(1);
    }

    /// @notice Test that reserved warrior can be minted under fair circumstances.
    function testCanMintReserved() public {
        mintWarriorToAddress(users[0], 8);

        warrior.mintReservedWarrior(1);
        assertEq(warrior.ownerOf(9), address(team));
        assertEq(warrior.ownerOf(10), address(community));
        assertEq(warrior.balanceOf(address(team)), 1);
        assertEq(warrior.balanceOf(address(community)), 1);
    }

    /// @notice Test multiple reserved warrior can be minted under fair circumstances.
    function testCanMintMultipleReserved() public {
        mintWarriorToAddress(users[0], 18);

        warrior.mintReservedWarrior(2);
        assertEq(warrior.ownerOf(19), address(team));
        assertEq(warrior.ownerOf(20), address(team));
        assertEq(warrior.ownerOf(21), address(community));
        assertEq(warrior.ownerOf(22), address(community));
        assertEq(warrior.balanceOf(address(team)), 2);
        assertEq(warrior.balanceOf(address(community)), 2);
    }

    /// @notice Test minting reserved warrior fails if not enough have warrior been minted.
    function testCantMintTooFastReserved() public {
        mintWarriorToAddress(users[0], 18);

        vm.expectRevert(ZeroWarrior.ReserveImbalance.selector);
        warrior.mintReservedWarrior(3);
    }

    /// @notice Test minting reserved warrior fails one by one if not enough have warrior been minted.
    function testCantMintTooFastReservedOneByOne() public {
        mintWarriorToAddress(users[0], 90);

        warrior.mintReservedWarrior(1);
        warrior.mintReservedWarrior(1);
        warrior.mintReservedWarrior(1);
        warrior.mintReservedWarrior(1);
        warrior.mintReservedWarrior(1);
        warrior.mintReservedWarrior(1);
        warrior.mintReservedWarrior(1);
        warrior.mintReservedWarrior(1);
        warrior.mintReservedWarrior(1);
        warrior.mintReservedWarrior(1);
        warrior.mintReservedWarrior(1);

        vm.expectRevert(ZeroWarrior.ReserveImbalance.selector);
        warrior.mintReservedWarrior(1);
    }

    function testCanMintZeroNameFromVirtualBalance() public {
        uint256 cost = warrior.warriorPrice();
        //mint initial warrior
        vm.prank(address(warrior));
        zero.mintForWarrior(users[0], cost);
        vm.prank(users[0]);
        warrior.mintFromZero(type(uint256).max, false);
        //warp for reveals
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");
        //warp until balance is larger than cost
        vm.warp(block.timestamp + 3 days);
        uint256 initialBalance = warrior.zeroBalance(users[0]);
        uint256 zeronamePrice = zeroname.zeronamePrice();
        console.log(zeronamePrice);
        assertTrue(initialBalance > zeronamePrice);
        //mint from balance
        vm.prank(users[0]);
        zeroname.mintFromZero(type(uint256).max, true);
        //asert owner is correct
        assertEq(zeroname.ownerOf(1), users[0]);
        //asert balance went down by expected amount
        uint256 finalBalance = warrior.zeroBalance(users[0]);
        uint256 paidZero = initialBalance - finalBalance;
        assertEq(paidZero, zeronamePrice);
    }

    function testCannotMintZeroNameWithInsufficientBalance() public {
        uint256 cost = warrior.warriorPrice();
        //mint initial warrior
        vm.prank(address(warrior));
        zero.mintForWarrior(users[0], cost);
        vm.prank(users[0]);
        warrior.mintFromZero(type(uint256).max, false);
        //warp for reveals
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");
        // try to mint from balance
        vm.prank(users[0]);
        vm.expectRevert(stdError.arithmeticError);
        zeroname.mintFromZero(type(uint256).max, true);
    }

    /*//////////////////////////////////////////////////////////////
                              PRICING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test VRGDA behavior when selling at target rate.
    function testPricingBasic() public {
        // VRGDA targets this number of mints at given time.
        uint256 timeDelta = 120 days;
        uint256 numMint = 876;

        vm.warp(block.timestamp + timeDelta);

        for (uint256 i = 0; i < numMint; ++i) {
            vm.startPrank(address(warrior));
            uint256 price = warrior.warriorPrice();
            zero.mintForWarrior(users[0], price);
            vm.stopPrank();
            vm.prank(users[0]);
            warrior.mintFromZero(price, false);
        }

        uint256 targetPrice = uint256(warrior.targetPrice());
        uint256 finalPrice = warrior.warriorPrice();

        // Equal within 3 percent since num mint is rounded from true decimal amount.
        assertRelApproxEq(finalPrice, targetPrice, 0.03e18);
    }

    /// @notice Pricing function should NOT revert when trying to price the last mintable warrior.
    function testDoesNotRevertEarly() public view {
        // This is the last warrior we expect to mint.
        int256 maxMintable = int256(warrior.MAX_MINTABLE()) * 1e18;
        // This call should NOT revert, since we should have a target date for the last mintable warrior.
        warrior.getTargetSaleTime(maxMintable);
    }

    /// @notice Pricing function should revert when trying to price beyond the last mintable warrior.
    function testDoesRevertWhenExpected() public {
        // One plus the max number of mintable warrior.
        int256 maxMintablePlusOne = int256(warrior.MAX_MINTABLE() + 1) * 1e18;
        // This call should revert, since there should be no target date beyond max mintable warrior.
        vm.expectRevert("UNDEFINED");
        warrior.getTargetSaleTime(maxMintablePlusOne);
    }

    /*//////////////////////////////////////////////////////////////
                           LEGENDARY APES
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that attempting to mint before start time reverts.
    function testLegendaryWarriorMintBeforeStart() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ZeroWarrior.LegendaryAuctionNotStarted.selector,
                warrior.LEGENDARY_AUCTION_INTERVAL()
            )
        );
        vm.prank(users[0]);
        warrior.mintLegendaryWarrior(ids);
    }

    /// @notice Test that Legendary Warrior initial price is what we expect.
    function testLegendaryWarriorTargetPrice() public {
        // Start of initial auction after initial interval is minted.
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL());
        uint256 cost = warrior.legendaryWarriorPrice();
        // Initial auction should start at a cost of 69.
        assertEq(cost, 69);
    }

    /// @notice Test that auction ends at a price of 0.
    function testLegendaryWarriorFinalPrice() public {
        // Mint 2 full intervals.
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL() * 2);
        uint256 cost = warrior.legendaryWarriorPrice();
        // Auction price should be 0 after full interval decay.
        assertEq(cost, 0);
    }

    /// @notice Test that auction ends at a price of 0 even after the interval.
    function testLegendaryWarriorPastFinalPrice() public {
        // Mint 3 full intervals.
        vm.warp(block.timestamp + 600 days);
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL() * 3);
        uint256 cost = warrior.legendaryWarriorPrice();
        // Auction price should be 0 after full interval decay.
        assertEq(cost, 0);
    }

    /// @notice Test that mid price happens when we expect.
    function testLegendaryWarriorMidPrice() public {
        // Mint first interval and half of second interval.
        mintWarriorToAddress(users[0], FixedPointMathLib.unsafeDivUp(warrior.LEGENDARY_AUCTION_INTERVAL() * 3, 2));
        uint256 cost = warrior.legendaryWarriorPrice();
        // Auction price should be cut by half mid way through auction.
        assertEq(cost, 35);
    }

    /// @notice Test that target price does't fall below what we expect.
    function testLegendaryWarriorMinStartPrice() public {
        // Mint two full intervals, such that price of first auction goes to zero.
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL() * 2);
        // Empty id list.
        uint256[] memory _ids;
        // Mint first auction at zero cost.
        warrior.mintLegendaryWarrior(_ids);
        // Start cost of next auction, which should equal 69.
        uint256 startCost = warrior.legendaryWarriorPrice();
        assertEq(startCost, 69);
    }

    /// @notice Test that Legendary Warrior can be minted.
    function testMintLegendaryWarrior() public {
        uint256 startTime = block.timestamp + 30 days;
        vm.warp(startTime);
        // Mint full interval to kick off first auction.
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL());
        uint256 cost = warrior.legendaryWarriorPrice();
        assertEq(cost, 69);
        setRandomnessAndReveal(cost, "seed");
        uint256 emissionMultipleSum;
        for (uint256 curId = 1; curId <= cost; curId++) {
            ids.push(curId);
            assertEq(warrior.ownerOf(curId), users[0]);
            emissionMultipleSum += warrior.getWarriorEmissionMultiple(curId);
        }

        assertEq(warrior.getUserEmissionMultiple(users[0]), emissionMultipleSum);

        vm.prank(users[0]);
        uint256 mintedLegendaryId = warrior.mintLegendaryWarrior(ids);

        // Legendary is owned by user.
        assertEq(warrior.ownerOf(mintedLegendaryId), users[0]);
        assertEq(warrior.getUserEmissionMultiple(users[0]), emissionMultipleSum * 2);

        assertEq(warrior.getWarriorEmissionMultiple(mintedLegendaryId), emissionMultipleSum * 2);

        for (uint256 i = 0; i < ids.length; ++i) {
            hevm.expectRevert("NOT_MINTED");
            warrior.ownerOf(ids[i]);
        }
    }

    /// @notice Test that owned counts are computed properly when minting a legendary
    function testLegendaryMintBalance() public {
        uint256 startTime = block.timestamp + 30 days;
        vm.warp(startTime);
        // Mint full interval to kick off first auction.
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL());
        uint256 cost = warrior.legendaryWarriorPrice();
        assertEq(cost, 69);
        setRandomnessAndReveal(cost, "seed");
        for (uint256 curId = 1; curId <= cost; curId++) {
            ids.push(curId);
        }

        uint256 initialBalance = warrior.balanceOf(users[0]);
        vm.prank(users[0]);
        warrior.mintLegendaryWarrior(ids);

        uint256 finalBalance = warrior.balanceOf(users[0]);

        // Check balance is computed correctly
        assertEq(finalBalance, initialBalance - cost + 1);
    }

    /// @notice Test that Legendary Warrior can be minted at 0 cost.
    function testMintFreeLegendaryWarrior() public {
        uint256 startTime = block.timestamp + 30 days;
        vm.warp(startTime);

        // Mint 2 full intervals to send price to zero.
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL() * 2);

        uint256 cost = warrior.legendaryWarriorPrice();
        assertEq(cost, 0);

        vm.prank(users[0]);
        uint256 mintedLegendaryId = warrior.mintLegendaryWarrior(ids);

        assertEq(warrior.ownerOf(mintedLegendaryId), users[0]);
        assertEq(warrior.getWarriorEmissionMultiple(mintedLegendaryId), 0);
    }

    /// @notice Test that Legendary Warrior can be minted at 0 cost.
    function testMintFreeLegendaryWarriorPastInterval() public {
        uint256 startTime = block.timestamp + 30 days;
        vm.warp(startTime);

        // Mint 3 full intervals to send price to zero.
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL() * 3);

        uint256 cost = warrior.legendaryWarriorPrice();
        assertEq(cost, 0);

        vm.prank(users[0]);
        uint256 mintedLegendaryId = warrior.mintLegendaryWarrior(ids);

        assertEq(warrior.ownerOf(mintedLegendaryId), users[0]);
        assertEq(warrior.getWarriorEmissionMultiple(mintedLegendaryId), 0);
    }

    /// @notice Test that legendary warrior can't be minted with insufficient payment.
    function testMintLegendaryWarriorWithInsufficientCost() public {
        uint256 startTime = block.timestamp + 30 days;
        vm.warp(startTime);
        // Mint full interval to kick off first auction.
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL());
        uint256 cost = warrior.legendaryWarriorPrice();
        assertEq(cost, 69);
        setRandomnessAndReveal(cost, "seed");
        uint256 emissionMultipleSum;
        for (uint256 curId = 1; curId <= cost; curId++) {
            ids.push(curId);
            assertEq(warrior.ownerOf(curId), users[0]);
            emissionMultipleSum += warrior.getWarriorEmissionMultiple(curId);
        }

        assertEq(warrior.getUserEmissionMultiple(users[0]), emissionMultipleSum);

        //remove one id such that payment is insufficient
        ids.pop();

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(ZeroWarrior.InsufficientWarriorAmount.selector, cost));
        warrior.mintLegendaryWarrior(ids);
    }

    /// @notice Test that legendary warrior can be minted with slipzeroname.
    function testMintLegendaryWarriorWithSlipzeroname() public {
        uint256 startTime = block.timestamp + 30 days;
        vm.warp(startTime);
        // Mint full interval to kick off first auction.
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL());
        uint256 cost = warrior.legendaryWarriorPrice();
        assertEq(cost, 69);
        setRandomnessAndReveal(cost, "seed");
        uint256 emissionMultipleSum;
        //add more ids than necessary
        for (uint256 curId = 1; curId <= cost + 10; curId++) {
            ids.push(curId);
            assertEq(warrior.ownerOf(curId), users[0]);
            emissionMultipleSum += warrior.getWarriorEmissionMultiple(curId);
        }

        vm.prank(users[0]);
        warrior.mintLegendaryWarrior(ids);

        //check full cost was burned
        for (uint256 curId = 1; curId <= cost; curId++) {
            hevm.expectRevert("NOT_MINTED");
            warrior.ownerOf(curId);
        }
        //check extra tokens were not burned
        for (uint256 curId = cost + 1; curId <= cost + 10; curId++) {
            assertEq(warrior.ownerOf(curId), users[0]);
        }
    }

    /// @notice Test that legendary warrior can't be minted if the user doesn't own one of the ids.
    function testMintLegendaryWarriorWithUnownedId() public {
        uint256 startTime = block.timestamp + 30 days;
        vm.warp(startTime);
        // Mint full interval to kick off first auction.
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL());
        uint256 cost = warrior.legendaryWarriorPrice();
        assertEq(cost, 69);
        setRandomnessAndReveal(cost, "seed");
        uint256 emissionMultipleSum;
        for (uint256 curId = 1; curId <= cost; curId++) {
            ids.push(curId);
            assertEq(warrior.ownerOf(curId), users[0]);
            emissionMultipleSum += warrior.getWarriorEmissionMultiple(curId);
        }

        assertEq(warrior.getUserEmissionMultiple(users[0]), emissionMultipleSum);

        ids.pop();
        ids.push(999);

        vm.prank(users[0]);
        vm.expectRevert("WRONG_FROM");
        warrior.mintLegendaryWarrior(ids);
    }

    /// @notice Test that legendary warrior have expected ids.
    function testMintLegendaryWarriorExpectedIds() public {
        // We expect the first legendary to have this id.
        uint256 nextMintLegendaryId = 9991;
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL());
        for (int256 i = 0; i < 10; ++i) {
            vm.warp(block.timestamp + 400 days);

            mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL());
            uint256 justMintedLegendaryId = warrior.mintLegendaryWarrior(ids);
            //assert that legendaries have the expected ids
            assertEq(nextMintLegendaryId, justMintedLegendaryId);
            nextMintLegendaryId++;
        }

        // Minting any more should fail.
        vm.expectRevert(ZeroWarrior.NoRemainingLegendaryWarrior.selector);
        warrior.mintLegendaryWarrior(ids);

        vm.expectRevert(ZeroWarrior.NoRemainingLegendaryWarrior.selector);
        warrior.legendaryWarriorPrice();
    }

    /// @notice Test that Legendary Warrior can't be burned to mint another legendary.
    function testCannotMintLegendaryWithLegendary() public {
        vm.warp(block.timestamp + 30 days);

        mintNextLegendary(users[0]);
        uint256 mintedLegendaryId = warrior.FIRST_LEGENDARY_APE_ID();
        //First legendary to be minted should be 9991
        assertEq(mintedLegendaryId, 9991);
        uint256 cost = warrior.legendaryWarriorPrice();

        // Starting price should be 69.
        assertEq(cost, 69);
        setRandomnessAndReveal(cost, "seed");
        for (uint256 i = 1; i <= cost; ++i) ids.push(i);

        ids[0] = mintedLegendaryId; // Try to zeroname in the legendary we just minted as well.
        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(ZeroWarrior.CannotBurnLegendary.selector, mintedLegendaryId));
        warrior.mintLegendaryWarrior(ids);
    }

    function testCanReuseSacrificedWarrior() public {
        address user = users[0];

        // setup legendary mint
        uint256 startTime = block.timestamp + 30 days;
        vm.warp(startTime);
        mintWarriorToAddress(user, warrior.LEGENDARY_AUCTION_INTERVAL());
        uint256 cost = warrior.legendaryWarriorPrice();
        assertEq(cost, 69);
        setRandomnessAndReveal(cost, "seed");

        for (uint256 curId = 1; curId <= cost; curId++) {
            ids.push(curId);
            assertEq(warrior.ownerOf(curId), users[0]);
        }

        // do token approvals for vulnerability exploit
        vm.startPrank(user);
        for (uint256 i = 0; i < ids.length; i++) {
            warrior.approve(user, ids[i]);
        }
        vm.stopPrank();

        // mint legendary
        vm.prank(user);
        uint256 mintedLegendaryId = warrior.mintLegendaryWarrior(ids);

        // confirm user owns legendary
        assertEq(warrior.ownerOf(mintedLegendaryId), user);

        // show that contract initially thinks tokens are burnt
        for (uint256 i = 0; i < ids.length; i++) {
            vm.expectRevert("NOT_MINTED");
            warrior.ownerOf(ids[i]);
        }

        // should not be able to revive burned warrior
        vm.startPrank(user);
        for (uint256 i = 0; i < ids.length; i++) {
            vm.expectRevert("NOT_AUTHORIZED");
            warrior.transferFrom(address(0), user, ids[i]);
        }
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                  URIS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test unminted URI is correct.
    function testUnmintedUri() public {
        hevm.expectRevert("NOT_MINTED");
        warrior.tokenURI(1);
    }

    /// @notice Test that unrevealed URI is correct.
    function testUnrevealedUri() public {
        uint256 warriorCost = warrior.warriorPrice();
        vm.prank(address(warrior));
        zero.mintForWarrior(users[0], warriorCost);
        vm.prank(users[0]);
        warrior.mintFromZero(type(uint256).max, false);
        // assert warrior not revealed after mint
        assertTrue(stringEquals(warrior.tokenURI(1), warrior.UNREVEALED_URI()));
    }

    /// @notice Test that revealed URI is correct.
    function testRevealedUri() public {
        mintWarriorToAddress(users[0], 1);
        // unrevealed warrior have 0 value attributes
        assertEq(warrior.getWarriorEmissionMultiple(1), 0);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");
        (, uint64 expectedIndex, ) = warrior.getWarriorData(1);
        string memory expectedURI = string(abi.encodePacked(warrior.BASE_URI(), uint256(expectedIndex).toString()));
        assertTrue(stringEquals(warrior.tokenURI(1), expectedURI));
    }

    /// @notice Test that legendary warrior URI is correct.
    function testMintedLegendaryURI() public {
        //mint legendary for free
        mintWarriorToAddress(users[0], warrior.LEGENDARY_AUCTION_INTERVAL() * 2);
        uint256 currentLegendaryId = warrior.mintLegendaryWarrior(ids);

        //expected URI should not be shuffled
        string memory expectedURI = string(
            abi.encodePacked(warrior.BASE_URI(), uint256(currentLegendaryId).toString())
        );
        string memory actualURI = warrior.tokenURI(currentLegendaryId);
        assertTrue(stringEquals(actualURI, expectedURI));
    }

    /// @notice Test that un-minted legendary warrior URI is correct.
    function testUnmintedLegendaryUri() public {
        uint256 currentLegendaryId = warrior.FIRST_LEGENDARY_APE_ID();

        hevm.expectRevert("NOT_MINTED");
        warrior.tokenURI(currentLegendaryId);

        hevm.expectRevert("NOT_MINTED");
        warrior.tokenURI(currentLegendaryId + 1);
    }

    /*//////////////////////////////////////////////////////////////
                                 REVEALS
    //////////////////////////////////////////////////////////////*/

    function testDoesNotAllowRevealingZero() public {
        vm.warp(block.timestamp + 24 hours);
        vm.expectRevert(ZeroWarrior.ZeroToBeRevealed.selector);
        warrior.requestRandomSeed();
    }

    /// @notice Cannot request random seed before 24 hours have zeronameed from initial mint.
    function testRevealDelayInitialMint() public {
        mintWarriorToAddress(users[0], 1);
        vm.expectRevert(ZeroWarrior.RequestTooEarly.selector);
        warrior.requestRandomSeed();
    }

    /// @notice Cannot reveal more warrior than remaining to be revealed.
    function testCannotRevealMoreWarriorThanRemainingToBeRevealed() public {
        mintWarriorToAddress(users[0], 1);

        vm.warp(block.timestamp + 24 hours);

        bytes32 requestId = warrior.requestRandomSeed();
        uint256 randomness = uint256(keccak256(abi.encodePacked("seed")));
        vrfCoordinator.callBackWithRandomness(requestId, randomness, address(randProvider));

        mintWarriorToAddress(users[0], 2);

        vm.expectRevert(abi.encodeWithSelector(ZeroWarrior.NotEnoughRemainingToBeRevealed.selector, 1));
        warrior.revealWarrior(2);
    }

    /// @notice Cannot request random seed before 24 hours have zeronameed from last reveal,
    function testRevealDelayRecurring() public {
        // Mint and reveal first warrior
        mintWarriorToAddress(users[0], 1);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");
        // Attempt reveal before 24 hours have zeronameed
        mintWarriorToAddress(users[0], 1);
        vm.expectRevert(ZeroWarrior.RequestTooEarly.selector);
        warrior.requestRandomSeed();
    }

    /// @notice Test that seed can't be set without first revealing pending warrior.
    function testCantSetRandomSeedWithoutRevealing() public {
        mintWarriorToAddress(users[0], 2);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");
        vm.warp(block.timestamp + 1 days);
        // should fail since there is one remaining warrior to be revealed with seed
        vm.expectRevert(ZeroWarrior.RevealsPending.selector);
        setRandomnessAndReveal(1, "seed");
    }

    /// @notice Test that revevals work as expected
    function testMultiReveal() public {
        mintWarriorToAddress(users[0], 100);
        // first 100 warrior should be unrevealed
        for (uint256 i = 1; i <= 100; ++i) {
            assertEq(warrior.tokenURI(i), warrior.UNREVEALED_URI());
        }

        vm.warp(block.timestamp + 1 days); // can only reveal every 24 hours

        setRandomnessAndReveal(50, "seed");
        // first 50 warrior should now be revealed
        for (uint256 i = 1; i <= 50; ++i) {
            assertTrue(!stringEquals(warrior.tokenURI(i), warrior.UNREVEALED_URI()));
        }
        // and next 50 should remain unrevealed
        for (uint256 i = 51; i <= 100; ++i) {
            assertTrue(stringEquals(warrior.tokenURI(i), warrior.UNREVEALED_URI()));
        }
    }

    function testCannotReuseSeedForReveal() public {
        // first mint and reveal.
        mintWarriorToAddress(users[0], 1);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");
        // seed used for first reveal.
        (uint64 firstSeed, , , , ) = warrior.warriorRevealsData();
        // second mint.
        mintWarriorToAddress(users[0], 1);
        vm.warp(block.timestamp + 1 days);
        warrior.requestRandomSeed();
        // seed we want to use for second reveal.
        (uint64 secondSeed, , , , ) = warrior.warriorRevealsData();
        // verify that we are trying to use the same seed.
        assertEq(firstSeed, secondSeed);
        // try to reveal with same seed, which should fail.
        vm.expectRevert(ZeroWarrior.SeedPending.selector);
        warrior.revealWarrior(1);
        assertTrue(true);
    }

    /*//////////////////////////////////////////////////////////////
                                  ZERO
    //////////////////////////////////////////////////////////////*/

    /// @notice test that zero balance grows as expected.
    function testSimpleRewards() public {
        mintWarriorToAddress(users[0], 1);
        // balance should initially be zero
        assertEq(warrior.zeroBalance(users[0]), 0);
        vm.warp(block.timestamp + 100000);
        // balance should be zero while no reveal
        assertEq(warrior.zeroBalance(users[0]), 0);
        setRandomnessAndReveal(1, "seed");
        // balance should NOT grow on same timestamp after reveal
        assertEq(warrior.zeroBalance(users[0]), 0);
        vm.warp(block.timestamp + 100000);
        // balance should grow after reveal
        assertGt(warrior.zeroBalance(users[0]), 0);
    }

    /// @notice Test that zero removal works as expected.
    function testZeroRemoval() public {
        mintWarriorToAddress(users[0], 1);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");
        vm.warp(block.timestamp + 100000);
        uint256 initialBalance = warrior.zeroBalance(users[0]);
        uint256 removalAmount = initialBalance / 10; //10%
        vm.prank(users[0]);
        warrior.removeZero(removalAmount);
        uint256 finalBalance = warrior.zeroBalance(users[0]);
        // balance should change
        assertTrue(initialBalance != finalBalance);
        assertEq(initialBalance, finalBalance + removalAmount);
        // user should have removed zero
        assertEq(zero.balanceOf(users[0]), removalAmount);
    }

    /// @notice Test that zero can't be removed when the balance is insufficient.
    function testCantRemoveZero() public {
        vm.warp(block.timestamp + 100000);
        mintWarriorToAddress(users[0], 1);
        setRandomnessAndReveal(1, "seed");
        vm.prank(users[0]);
        vm.expectRevert(stdError.arithmeticError);
        // can't remove, since balance should be zero.
        warrior.removeZero(1);
    }

    /// @notice Test that adding zero is reflected in balance.
    function testZeroAddition() public {
        mintWarriorToAddress(users[0], 1);
        assertEq(warrior.getWarriorEmissionMultiple(1), 0);
        assertEq(warrior.getUserEmissionMultiple(users[0]), 0);
        // waiting after mint to reveal shouldn't affect balance
        vm.warp(block.timestamp + 100000);
        assertEq(warrior.zeroBalance(users[0]), 0);
        setRandomnessAndReveal(1, "seed");
        uint256 warriorMultiple = warrior.getWarriorEmissionMultiple(1);
        assertGt(warriorMultiple, 0);
        assertEq(warrior.getUserEmissionMultiple(users[0]), warriorMultiple);
        vm.prank(address(warrior));
        uint256 additionAmount = 1000;
        zero.mintForWarrior(users[0], additionAmount);
        vm.prank(users[0]);
        warrior.addZero(additionAmount);
        assertEq(warrior.zeroBalance(users[0]), additionAmount);
    }

    /// @notice Test that we can't add zero when we don't have the corresponding ERC20 balance.
    function testCantAddMoreZeroThanOwned() public {
        mintWarriorToAddress(users[0], 1);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");
        vm.prank(users[0]);
        vm.expectRevert(stdError.arithmeticError);
        warrior.addZero(10000);
    }

    /// @notice make sure that actions that trigger balance snapshotting do not affect total balance.
    function testSnapshotDoesNotAffectBalance() public {
        //mint one warrior for each user
        mintWarriorToAddress(users[0], 1);
        mintWarriorToAddress(users[1], 1);
        vm.warp(block.timestamp + 1 days);
        //give user initial zero balance
        vm.prank(address(warrior));
        zero.mintForWarrior(users[0], 100);
        //reveal warrior
        bytes32 requestId = warrior.requestRandomSeed();
        uint256 randomness = 1022; // magic seed to ensure both warrior have same multiplier
        vrfCoordinator.callBackWithRandomness(requestId, randomness, address(randProvider));
        warrior.revealWarrior(2);
        //make sure both warrior have same multiple, and same starting balance
        assertGt(warrior.getUserEmissionMultiple(users[0]), 0);
        assertEq(warrior.getUserEmissionMultiple(users[0]), warrior.getUserEmissionMultiple(users[1]));
        uint256 initialBalanceZero = warrior.zeroBalance(users[0]);
        uint256 initialBalanceOne = warrior.zeroBalance(users[1]);
        assertEq(initialBalanceZero, initialBalanceOne);
        vm.warp(block.timestamp + 5 days);
        //Add and remove one unit of zero to trigger snapshot
        vm.startPrank(users[0]);
        warrior.addZero(1);
        warrior.removeZero(1);
        vm.stopPrank();
        //One more time
        vm.warp(block.timestamp + 5 days);
        vm.startPrank(users[0]);
        warrior.addZero(1);
        warrior.removeZero(1);
        vm.stopPrank();
        // make sure users have equal balance
        vm.warp(block.timestamp + 5 days);
        assertGt(warrior.getUserEmissionMultiple(users[0]), initialBalanceZero);
        assertEq(warrior.zeroBalance(users[0]), warrior.zeroBalance(users[1]));
    }

    /// @notice Test that emission multiple changes as expected after transfer.
    function testEmissionMultipleUpdatesAfterTransfer() public {
        mintWarriorToAddress(users[0], 1);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");

        uint256 initialUserMultiple = warrior.getUserEmissionMultiple(users[0]);
        assertGt(initialUserMultiple, 0);
        assertEq(warrior.getUserEmissionMultiple(users[1]), 0);

        assertEq(warrior.balanceOf(address(users[0])), 1);
        assertEq(warrior.balanceOf(address(users[1])), 0);

        vm.prank(users[0]);
        warrior.transferFrom(users[0], users[1], 1);

        assertEq(warrior.getUserEmissionMultiple(users[0]), 0);
        assertEq(warrior.getUserEmissionMultiple(users[1]), initialUserMultiple);

        assertEq(warrior.balanceOf(address(users[0])), 0);
        assertEq(warrior.balanceOf(address(users[1])), 1);
    }

    /// @notice Test that warrior balances are accurate after transfer.
    function testWarriorBalancesAfterTransfer() public {
        mintWarriorToAddress(users[0], 1);
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");

        vm.warp(block.timestamp + 1000000);

        uint256 userOneBalance = warrior.zeroBalance(users[0]);
        uint256 userTwoBalance = warrior.zeroBalance(users[1]);
        //user with warrior should have non-zero balance
        assertGt(userOneBalance, 0);
        //other user should have zero balance
        assertEq(userTwoBalance, 0);
        //transfer warrior
        vm.prank(users[0]);
        warrior.transferFrom(users[0], users[1], 1);
        //balance should not change after transfer
        assertEq(warrior.zeroBalance(users[0]), userOneBalance);
        assertEq(warrior.zeroBalance(users[1]), userTwoBalance);
    }

    /*//////////////////////////////////////////////////////////////
                               FEEDING ART
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that zeroname can be fed to warrior.
    function testFeedingArt() public {
        address user = users[0];
        mintWarriorToAddress(user, 1);
        uint256 zeronamePrice = zeroname.zeronamePrice();
        vm.prank(address(warrior));
        zero.mintForWarrior(user, zeronamePrice);
        vm.startPrank(user);
        zeroname.mintFromZero(type(uint256).max, false);
        warrior.warrior(1, address(zeroname), 1, false);
        vm.stopPrank();
        assertEq(warrior.getCopiesOfZeroWarrioredByWarrior(1, address(zeroname), 1), 1);
    }

    /// @notice Test that you can't feed art to warrior you don't own.
    function testCantwarriorToUnownedWarrior() public {
        address user = users[0];
        uint256 zeronamePrice = zeroname.zeronamePrice();
        vm.prank(address(warrior));
        zero.mintForWarrior(user, zeronamePrice);
        vm.startPrank(user);
        zeroname.mintFromZero(type(uint256).max, false);
        vm.expectRevert(abi.encodeWithSelector(ZeroWarrior.OwnerMismatch.selector, address(0)));
        warrior.warrior(1, address(zeroname), 1, false);
        vm.stopPrank();
    }

    /// @notice Test that you can't feed art you don't own to your warrior.
    function testCantFeedUnownedArt() public {
        address user = users[0];
        mintWarriorToAddress(user, 1);
        vm.startPrank(user);
        vm.expectRevert("WRONG_FROM");
        warrior.warrior(1, address(zeroname), 1, false);
        vm.stopPrank();
    }

    /// @notice Test that warrior can't eat other warrior
    function testCantFeedWarrior() public {
        address user = users[0];
        mintWarriorToAddress(user, 2);
        vm.startPrank(user);
        vm.expectRevert(ZeroWarrior.Cannibalism.selector);
        warrior.warrior(1, address(warrior), 2, true);
        vm.stopPrank();
    }

    function testCantFeed721As1155() public {
        address user = users[0];
        mintWarriorToAddress(user, 1);
        uint256 zeronamePrice = zeroname.zeronamePrice();
        vm.prank(address(warrior));
        zero.mintForWarrior(user, zeronamePrice);
        vm.startPrank(user);
        zeroname.mintFromZero(type(uint256).max, false);
        vm.expectRevert();
        warrior.warrior(1, address(zeroname), 1, true);
    }

    function testFeeding1155() public {
        address user = users[0];
        mintWarriorToAddress(user, 1);
        MockERC1155 token = new MockERC1155();
        token.mint(user, 0, 1, "");
        vm.startPrank(user);
        token.setApprovalForAll(address(warrior), true);
        warrior.warrior(1, address(token), 0, true);
        vm.stopPrank();
        assertEq(warrior.getCopiesOfZeroWarrioredByWarrior(1, address(token), 0), 1);
    }

    function testFeedingMultiple1155Copies() public {
        address user = users[0];
        mintWarriorToAddress(user, 1);
        MockERC1155 token = new MockERC1155();
        token.mint(user, 0, 5, "");
        vm.startPrank(user);
        token.setApprovalForAll(address(warrior), true);
        warrior.warrior(1, address(token), 0, true);
        warrior.warrior(1, address(token), 0, true);
        warrior.warrior(1, address(token), 0, true);
        warrior.warrior(1, address(token), 0, true);
        warrior.warrior(1, address(token), 0, true);
        vm.stopPrank();
        assertEq(warrior.getCopiesOfZeroWarrioredByWarrior(1, address(token), 0), 5);
    }

    function testCantFeed1155As721() public {
        address user = users[0];
        mintWarriorToAddress(user, 1);
        MockERC1155 token = new MockERC1155();
        token.mint(user, 0, 1, "");
        vm.startPrank(user);
        token.setApprovalForAll(address(warrior), true);
        vm.expectRevert();
        warrior.warrior(1, address(token), 0, false);
    }

    /*//////////////////////////////////////////////////////////////
                           LONG-RUNNING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check that max supply is mintable
    function testLongRunningMintMaxFromZero() public {
        uint256 maxMintableWithZero = warrior.MAX_MINTABLE();

        for (uint256 i = 0; i < maxMintableWithZero; ++i) {
            vm.warp(block.timestamp + 1 days);
            uint256 cost = warrior.warriorPrice();
            vm.prank(address(warrior));
            zero.mintForWarrior(users[0], cost);
            vm.prank(users[0]);
            warrior.mintFromZero(type(uint256).max, false);
        }
    }

    /// @notice Check that minting beyond max supply should revert.
    function testLongRunningMintMaxFromZeroRevert() public {
        uint256 maxMintableWithZero = warrior.MAX_MINTABLE();

        for (uint256 i = 0; i < maxMintableWithZero + 1; ++i) {
            vm.warp(block.timestamp + 1 days);

            if (i == maxMintableWithZero) vm.expectRevert("UNDEFINED");
            uint256 cost = warrior.warriorPrice();

            vm.prank(address(warrior));
            zero.mintForWarrior(users[0], cost);
            vm.prank(users[0]);

            if (i == maxMintableWithZero) vm.expectRevert("UNDEFINED");
            warrior.mintFromZero(type(uint256).max, false);
        }
    }

    /// @notice Check that max reserved supplies are mintable.
    function testLongRunningMintMaxReserved() public {
        uint256 maxMintableWithZero = warrior.MAX_MINTABLE();

        for (uint256 i = 0; i < maxMintableWithZero; ++i) {
            vm.warp(block.timestamp + 1 days);
            uint256 cost = warrior.warriorPrice();
            vm.prank(address(warrior));
            zero.mintForWarrior(users[0], cost);
            vm.prank(users[0]);
            warrior.mintFromZero(type(uint256).max, false);
        }

        warrior.mintReservedWarrior(warrior.RESERVED_SUPPLY() / 2);
    }

    /// @notice Check that minting reserves beyond their max supply reverts.
    function testLongRunningMintMaxTeamRevert() public {
        uint256 maxMintableWithZero = warrior.MAX_MINTABLE();

        for (uint256 i = 0; i < maxMintableWithZero; ++i) {
            vm.warp(block.timestamp + 1 days);
            uint256 cost = warrior.warriorPrice();
            vm.prank(address(warrior));
            zero.mintForWarrior(users[0], cost);
            vm.prank(users[0]);
            warrior.mintFromZero(type(uint256).max, false);
        }

        warrior.mintReservedWarrior(warrior.RESERVED_SUPPLY() / 2);

        vm.expectRevert(ZeroWarrior.ReserveImbalance.selector);
        warrior.mintReservedWarrior(1);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint a number of warrior to the given address
    function mintWarriorToAddress(address addr, uint256 num) internal {
        for (uint256 i = 0; i < num; ++i) {
            vm.startPrank(address(warrior));
            zero.mintForWarrior(addr, warrior.warriorPrice());
            vm.stopPrank();

            uint256 warriorOwnedBefore = warrior.balanceOf(addr);

            vm.prank(addr);
            warrior.mintFromZero(type(uint256).max, false);

            assertEq(warrior.balanceOf(addr), warriorOwnedBefore + 1);
        }
    }

    /// @notice Call back vrf with randomness and reveal warrior.
    function setRandomnessAndReveal(uint256 numReveal, string memory seed) internal {
        bytes32 requestId = warrior.requestRandomSeed();
        uint256 randomness = uint256(keccak256(abi.encodePacked(seed)));
        // call back from coordinator
        vrfCoordinator.callBackWithRandomness(requestId, randomness, address(randProvider));
        warrior.revealWarrior(numReveal);
    }

    /// @notice Check for string equality.
    function stringEquals(string memory s1, string memory s2) internal pure returns (bool) {
        return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }

    function mintNextLegendary(address addr) internal {
        uint256[] memory id;
        mintWarriorToAddress(addr, warrior.LEGENDARY_AUCTION_INTERVAL() * 2);
        vm.prank(addr);
        warrior.mintLegendaryWarrior(id);
    }
}
