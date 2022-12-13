// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {toWadUnsafe, toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

import {LibZERO} from "zero-issuance/LibZERO.sol";
import {LogisticVRGDA} from "VRGDAs/LogisticVRGDA.sol";

import {RandProvider} from "./utils/rand/RandProvider.sol";
import {WarriorERC721} from "./utils/token/WarriorERC721.sol";

import {Zero} from "./Zero.sol";
import {ZeroName} from "./ZeroName.sol";


contract ZeroWarrior is WarriorERC721, LogisticVRGDA, Owned, ERC1155TokenReceiver {
    using LibString for uint256;
    using FixedPointMathLib for uint256;

    Zero public immutable zero;

    ZeroName public immutable zeroname;

    address public immutable team;

    address public immutable community;

    RandProvider public randProvider;

    uint256 public constant MAX_SUPPLY = 10000;

    uint256 public constant MINTLIST_SUPPLY = 2000;

    uint256 public constant LEGENDARY_SUPPLY = 10;

    uint256 public constant RESERVED_SUPPLY = (MAX_SUPPLY - MINTLIST_SUPPLY - LEGENDARY_SUPPLY) / 5;

    uint256 public constant MAX_MINTABLE = MAX_SUPPLY
        - MINTLIST_SUPPLY
        - LEGENDARY_SUPPLY
        - RESERVED_SUPPLY;
    
    bytes32 public immutable PROVENANCE_HASH;

    string public UNREVEALED_URI;

    string public BASE_URI;

    bytes32 public immutable merkleRoot;

    mapping(address => bool) public hasClaimedMintlistWarrior;

    uint256 public immutable mintStart;

    uint128 public numMintedFromZero;

    uint128 public currentNonLegendaryId;

    uint256 public numMintedForReserves;

    uint256 public constant LEGENDARY_APE_INITIAL_START_PRICE = 69;

    uint256 public constant FIRST_LEGENDARY_APE_ID = MAX_SUPPLY - LEGENDARY_SUPPLY + 1;

    uint256 public constant LEGENDARY_AUCTION_INTERVAL = MAX_MINTABLE / (LEGENDARY_SUPPLY + 1);

    struct LegendaryWarriorAuctionData {
        uint128 startPrice;
        uint128 numSold;
    }

    LegendaryWarriorAuctionData public legendaryWarriorAuctionData;

    struct WarriorRevealsData {
        uint64 randomSeed;
        uint64 nextRevealTimestamp;
        uint64 lastRevealedId;
        uint56 toBeRevealed;
        bool waitingForSeed;
    }

    WarriorRevealsData public warriorRevealsData;

    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public getCopiesOfZeroWarrioredByWarrior;

    event ZeroBalanceUpdated(address indexed user, uint256 newZeroBalance);

    event WarriorClaimed(address indexed user, uint256 indexed warriorId);
    event WarriorPurchased(address indexed user, uint256 indexed warriorId, uint256 price);
    event LegendaryWarriorMinted(address indexed user, uint256 indexed warriorId, uint256[] burnedWarriorIds);
    event ReservedWarriorMinted(address indexed user, uint256 lastMintedWarriorId, uint256 numWarriorEach);

    event RandomnessFulfilled(uint256 randomness);
    event RandomnessRequested(address indexed user, uint256 toBeRevealed);
    event RandProviderUpgraded(address indexed user, RandProvider indexed newRandProvider);

    event WarriorRevealed(address indexed user, uint256 numWarrior, uint256 lastRevealedId);

    event ZeroWarriored(address indexed user, uint256 indexed warriorId, address indexed nft, uint256 id);

    error InvalidProof();
    error AlreadyClaimed();
    error MintStartPending();

    error SeedPending();
    error RevealsPending();
    error RequestTooEarly();
    error ZeroToBeRevealed();
    error NotRandProvider();

    error ReserveImbalance();

    error Cannibalism();
    error OwnerMismatch(address owner);

    error NoRemainingLegendaryWarrior();
    error CannotBurnLegendary(uint256 warriorId);
    error InsufficientWarriorAmount(uint256 cost);
    error LegendaryAuctionNotStarted(uint256 warriorLeft);

    error PriceExceededMax(uint256 currentPrice);

    error NotEnoughRemainingToBeRevealed(uint256 totalRemainingToBeRevealed);

    error UnauthorizedCaller(address caller);

    constructor(
        bytes32 _merkleRoot,
        uint256 _mintStart,
        Zero _zero,
        ZeroName _zeroname,
        address _team,
        address _community,
        RandProvider _randProvider,
        string memory _baseUri,
        string memory _unrevealedUri,
        bytes32 _provenanceHash
    )
        WarriorERC721("Zero Warrior NFT", "ZeroWarrior")
        Owned(msg.sender)
        LogisticVRGDA(
            69.42e18,
            0.31e18,
            toWadUnsafe(MAX_MINTABLE),
            0.0023e18
        )
    {
        mintStart = _mintStart;
        merkleRoot = _merkleRoot;

        zero = _zero;
        zeroname = _zeroname;
        team = _team;
        community = _community;
        randProvider = _randProvider;

        BASE_URI = _baseUri;
        UNREVEALED_URI = _unrevealedUri;

        PROVENANCE_HASH = _provenanceHash;

        legendaryWarriorAuctionData.startPrice = uint128(LEGENDARY_APE_INITIAL_START_PRICE);

        warriorRevealsData.nextRevealTimestamp = uint64(_mintStart + 1 days);
    }

    function claimWarrior(bytes32[] calldata proof) external returns (uint256 warriorId) {
        if (mintStart > block.timestamp) revert MintStartPending();

        if (hasClaimedMintlistWarrior[msg.sender]) revert AlreadyClaimed();

        if (!MerkleProofLib.verify(proof, merkleRoot, keccak256(abi.encodePacked(msg.sender)))) revert InvalidProof();

        hasClaimedMintlistWarrior[msg.sender] = true;

        unchecked {
            emit WarriorClaimed(msg.sender, warriorId = ++currentNonLegendaryId);
        }

        _mint(msg.sender, warriorId);
    }


    function mintFromZero(uint256 maxPrice, bool useVirtualBalance) external returns (uint256 warriorId) {
        uint256 currentPrice = warriorPrice();

        if (currentPrice > maxPrice) revert PriceExceededMax(currentPrice);

        useVirtualBalance
            ? updateUserZeroBalance(msg.sender, currentPrice, ZeroBalanceUpdateType.DECREASE)
            : zero.burnForWarrior(msg.sender, currentPrice);

        unchecked {
            ++numMintedFromZero; 

            emit WarriorPurchased(msg.sender, warriorId = ++currentNonLegendaryId, currentPrice);
        }

        _mint(msg.sender, warriorId);
    }

    function warriorPrice() public view returns (uint256) {
        uint256 timeSinceStart = block.timestamp - mintStart;

        return getVRGDAPrice(toDaysWadUnsafe(timeSinceStart), numMintedFromZero);
    }

    
    function mintLegendaryWarrior(uint256[] calldata warriorIds) external returns (uint256 warriorId) {
        uint256 numSold = legendaryWarriorAuctionData.numSold;

        warriorId = FIRST_LEGENDARY_APE_ID + numSold;

        uint256 cost = legendaryWarriorPrice();

        if (warriorIds.length < cost) revert InsufficientWarriorAmount(cost);

        unchecked {
            uint256 burnedMultipleTotal;

            uint256 id;

            for (uint256 i = 0; i < cost; ++i) {
                id = warriorIds[i];

                if (id >= FIRST_LEGENDARY_APE_ID) revert CannotBurnLegendary(id);

                WarriorData storage warrior = getWarriorData[id];

                require(warrior.owner == msg.sender, "WRONG_FROM");

                burnedMultipleTotal += warrior.emissionMultiple;

                delete getApproved[id];

                emit Transfer(msg.sender, warrior.owner = address(0), id);
            }

            getWarriorData[warriorId].emissionMultiple = uint32(burnedMultipleTotal * 2);

            getUserData[msg.sender].lastBalance = uint128(zeroBalance(msg.sender));
            getUserData[msg.sender].lastTimestamp = uint64(block.timestamp);
            getUserData[msg.sender].emissionMultiple += uint32(burnedMultipleTotal);
            getUserData[msg.sender].warriorOwned -= uint32(cost);

            legendaryWarriorAuctionData.startPrice = uint128(
                cost <= LEGENDARY_APE_INITIAL_START_PRICE / 2 ? LEGENDARY_APE_INITIAL_START_PRICE : cost * 2
            );
            legendaryWarriorAuctionData.numSold = uint128(numSold + 1); // Increment the # of legendaries sold.

            emit LegendaryWarriorMinted(msg.sender, warriorId, warriorIds[:cost]);

            _mint(msg.sender, warriorId);
        }
    }

    function legendaryWarriorPrice() public view returns (uint256) {
        uint256 startPrice = legendaryWarriorAuctionData.startPrice;
        uint256 numSold = legendaryWarriorAuctionData.numSold;

        if (numSold == LEGENDARY_SUPPLY) revert NoRemainingLegendaryWarrior();

        unchecked {
            uint256 mintedFromZero = numMintedFromZero;

            uint256 numMintedAtStart = (numSold + 1) * LEGENDARY_AUCTION_INTERVAL;

            if (numMintedAtStart > mintedFromZero) revert LegendaryAuctionNotStarted(numMintedAtStart - mintedFromZero);

            uint256 numMintedSinceStart = mintedFromZero - numMintedAtStart;

            if (numMintedSinceStart >= LEGENDARY_AUCTION_INTERVAL) return 0;
            else return FixedPointMathLib.unsafeDivUp(startPrice * (LEGENDARY_AUCTION_INTERVAL - numMintedSinceStart), LEGENDARY_AUCTION_INTERVAL);
        }
    }

    function requestRandomSeed() external returns (bytes32) {
        uint256 nextRevealTimestamp = warriorRevealsData.nextRevealTimestamp;

        if (block.timestamp < nextRevealTimestamp) revert RequestTooEarly();

        if (warriorRevealsData.toBeRevealed != 0) revert RevealsPending();

        unchecked {
            warriorRevealsData.waitingForSeed = true;

            uint256 toBeRevealed = currentNonLegendaryId - warriorRevealsData.lastRevealedId;

            if (toBeRevealed == 0) revert ZeroToBeRevealed();

            warriorRevealsData.toBeRevealed = uint56(toBeRevealed);

            warriorRevealsData.nextRevealTimestamp = uint64(nextRevealTimestamp + 1 days);

            emit RandomnessRequested(msg.sender, toBeRevealed);
        }

        return randProvider.requestRandomBytes();
    }

    function acceptRandomSeed(bytes32, uint256 randomness) external {
        if (msg.sender != address(randProvider)) revert NotRandProvider();

        warriorRevealsData.randomSeed = uint64(randomness);

        warriorRevealsData.waitingForSeed = false;

        emit RandomnessFulfilled(randomness);
    }

    function upgradeRandProvider(RandProvider newRandProvider) external onlyOwner {
        if (warriorRevealsData.waitingForSeed) {
            warriorRevealsData.waitingForSeed = false;
            warriorRevealsData.toBeRevealed = 0;
            warriorRevealsData.nextRevealTimestamp -= 1 days;
        }

        randProvider = newRandProvider;

        emit RandProviderUpgraded(msg.sender, newRandProvider);
    }

    function revealWarrior(uint256 numWarrior) external {
        uint256 randomSeed = warriorRevealsData.randomSeed;

        uint256 lastRevealedId = warriorRevealsData.lastRevealedId;

        uint256 totalRemainingToBeRevealed = warriorRevealsData.toBeRevealed;

        if (warriorRevealsData.waitingForSeed) revert SeedPending();

        if (numWarrior > totalRemainingToBeRevealed) revert NotEnoughRemainingToBeRevealed(totalRemainingToBeRevealed);

        unchecked {
            for (uint256 i = 0; i < numWarrior; ++i) {
                uint256 remainingIds = FIRST_LEGENDARY_APE_ID - lastRevealedId - 1;

                uint256 distance = randomSeed % remainingIds;

                uint256 currentId = ++lastRevealedId;

                uint256 swapId = currentId + distance;

                uint64 swapIndex = getWarriorData[swapId].idx == 0
                    ? uint64(swapId)
                    : getWarriorData[swapId].idx;

                address currentIdOwner = getWarriorData[currentId].owner;

                uint64 currentIndex = getWarriorData[currentId].idx == 0
                    ? uint64(currentId)
                    : getWarriorData[currentId].idx;

                uint256 newCurrentIdMultiple = 9;

                assembly {
                    newCurrentIdMultiple := sub(sub(sub(
                        newCurrentIdMultiple,
                        lt(swapIndex, 7964)),
                        lt(swapIndex, 5673)),
                        lt(swapIndex, 3055)
                    )
                }

                getWarriorData[currentId].idx = swapIndex;
                getWarriorData[currentId].emissionMultiple = uint32(newCurrentIdMultiple);

                getWarriorData[swapId].idx = currentIndex;

                getUserData[currentIdOwner].lastBalance = uint128(zeroBalance(currentIdOwner));
                getUserData[currentIdOwner].lastTimestamp = uint64(block.timestamp);
                getUserData[currentIdOwner].emissionMultiple += uint32(newCurrentIdMultiple);

                assembly {
                    mstore(0, randomSeed)

                    randomSeed := mod(keccak256(0, 32), exp(2, 64))
                }
            }

            warriorRevealsData.randomSeed = uint64(randomSeed);
            warriorRevealsData.lastRevealedId = uint64(lastRevealedId);
            warriorRevealsData.toBeRevealed = uint56(totalRemainingToBeRevealed - numWarrior);

            emit WarriorRevealed(msg.sender, numWarrior, lastRevealedId);
        }
    }

    function tokenURI(uint256 warriorId) public view virtual override returns (string memory) {
        if (warriorId <= warriorRevealsData.lastRevealedId) {
            if (warriorId == 0) revert("NOT_MINTED"); // 0 is not a valid id for Zero Warrior.

            return string.concat(BASE_URI, uint256(getWarriorData[warriorId].idx).toString());
        }

        if (warriorId <= currentNonLegendaryId) return UNREVEALED_URI;

        if (warriorId < FIRST_LEGENDARY_APE_ID) revert("NOT_MINTED");

        if (warriorId < FIRST_LEGENDARY_APE_ID + legendaryWarriorAuctionData.numSold)
            return string.concat(BASE_URI, warriorId.toString());

        revert("NOT_MINTED");
    }

    function warrior(
        uint256 warriorId,
        address nft,
        uint256 id,
        bool isERC1155
    ) external {
        address owner = getWarriorData[warriorId].owner;

        if (owner != msg.sender) revert OwnerMismatch(owner);

        if (nft == address(this)) revert Cannibalism();

        unchecked {
            ++getCopiesOfZeroWarrioredByWarrior[warriorId][nft][id];
        }

        emit ZeroWarriored(msg.sender, warriorId, nft, id);

        isERC1155
            ? ERC1155(nft).safeTransferFrom(msg.sender, address(this), id, 1, "")
            : ERC721(nft).transferFrom(msg.sender, address(this), id);
    }

   function zeroBalance(address user) public view returns (uint256) {
        return LibZERO.computeZEROBalance(
            getUserData[user].emissionMultiple,
            getUserData[user].lastBalance,
            uint256(toDaysWadUnsafe(block.timestamp - getUserData[user].lastTimestamp))
        );
    }

    function addZero(uint256 zeroAmount) external {
        zero.burnForWarrior(msg.sender, zeroAmount);

        updateUserZeroBalance(msg.sender, zeroAmount, ZeroBalanceUpdateType.INCREASE);
    }

    function removeZero(uint256 zeroAmount) external {
        updateUserZeroBalance(msg.sender, zeroAmount, ZeroBalanceUpdateType.DECREASE);

        zero.mintForWarrior(msg.sender, zeroAmount);
    }

    function burnZeroForZeroName(address user, uint256 zeroAmount) external {
        if (msg.sender != address(zeroname)) revert UnauthorizedCaller(msg.sender);

        updateUserZeroBalance(user, zeroAmount, ZeroBalanceUpdateType.DECREASE);
    }

    enum ZeroBalanceUpdateType {
        INCREASE,
        DECREASE
    }

    function updateUserZeroBalance(
        address user,
        uint256 zeroAmount,
        ZeroBalanceUpdateType updateType
    ) internal {
        uint256 updatedBalance = updateType == ZeroBalanceUpdateType.INCREASE
            ? zeroBalance(user) + zeroAmount
            : zeroBalance(user) - zeroAmount;

        getUserData[user].lastBalance = uint128(updatedBalance);
        getUserData[user].lastTimestamp = uint64(block.timestamp);

        emit ZeroBalanceUpdated(user, updatedBalance);
    }

    function mintReservedWarrior(uint256 numWarriorEach) external returns (uint256 lastMintedWarriorId) {
        unchecked {
            uint256 newNumMintedForReserves = numMintedForReserves += (numWarriorEach * 2);

            if (newNumMintedForReserves > (numMintedFromZero + newNumMintedForReserves) / 5) revert ReserveImbalance();
        }

        lastMintedWarriorId = _batchMint(team, numWarriorEach, currentNonLegendaryId);
        lastMintedWarriorId = _batchMint(community, numWarriorEach, lastMintedWarriorId);

        currentNonLegendaryId = uint128(lastMintedWarriorId); // Set currentNonLegendaryId.

        emit ReservedWarriorMinted(msg.sender, lastMintedWarriorId, numWarriorEach);
    }

    function getWarriorEmissionMultiple(uint256 warriorId) external view returns (uint256) {
        return getWarriorData[warriorId].emissionMultiple;
    }

    function getUserEmissionMultiple(address user) external view returns (uint256) {
        return getUserData[user].emissionMultiple;
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        require(from == getWarriorData[id].owner, "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        delete getApproved[id];

        getWarriorData[id].owner = to;

        unchecked {
            uint32 emissionMultiple = getWarriorData[id].emissionMultiple; 

            getUserData[from].lastBalance = uint128(zeroBalance(from));
            getUserData[from].lastTimestamp = uint64(block.timestamp);
            getUserData[from].emissionMultiple -= emissionMultiple;
            getUserData[from].warriorOwned -= 1;

            getUserData[to].lastBalance = uint128(zeroBalance(to));
            getUserData[to].lastTimestamp = uint64(block.timestamp);
            getUserData[to].emissionMultiple += emissionMultiple;
            getUserData[to].warriorOwned += 1;
        }

        emit Transfer(from, to, id);
    }
}
