// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {LibString} from "solmate/utils/LibString.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

import {LogisticToLinearVRGDA} from "VRGDAs/LogisticToLinearVRGDA.sol";

import {ZeroNameERC721} from "./utils/token/ZeroNameERC721.sol";

import {Zero} from "./Zero.sol";
import {ZeroWarrior} from "./ZeroWarrior.sol";

contract ZeroName is ZeroNameERC721, LogisticToLinearVRGDA {
    using LibString for uint256;

    Zero public immutable zero;

    address public immutable community;

    string public BASE_URI;

    uint256 public immutable mintStart;

    uint128 public currentId;

    uint128 public numMintedForCommunity;

    int256 internal constant SWITCH_DAY_WAD = 233e18;

    int256 internal constant SOLD_BY_SWITCH_WAD = 8336.760939794622713006e18;


    event ZeroNamePurchased(address indexed user, uint256 indexed zeronameId, uint256 price);

    event CommunityZeroNameMinted(address indexed user, uint256 lastMintedZeroNameId, uint256 numZeroName);

    error ReserveImbalance();

    error PriceExceededMax(uint256 currentPrice);

    constructor(
        uint256 _mintStart,
        Zero _zero,
        address _community,
        ZeroWarrior _zeroWarrior,
        string memory _baseUri
    )
        ZeroNameERC721(_zeroWarrior, "Zero Name NFT", "ZeroName")
        LogisticToLinearVRGDA(
            4.2069e18, 
            0.31e18,
            9000e18,
            0.014e18,
            SOLD_BY_SWITCH_WAD,
            SWITCH_DAY_WAD,
            9e18
        )
    {
        mintStart = _mintStart;

        zero = _zero;

        community = _community;

        BASE_URI = _baseUri;
    }

    function mintFromZero(uint256 maxPrice, bool useVirtualBalance) external returns (uint256 zeronameId) {
        uint256 currentPrice = zeronamePrice();

        if (currentPrice > maxPrice) revert PriceExceededMax(currentPrice);

        useVirtualBalance
            ? zeroWarrior.burnZeroForZeroName(msg.sender, currentPrice)
            : zero.burnForZeroName(msg.sender, currentPrice);

        unchecked {
            emit ZeroNamePurchased(msg.sender, zeronameId = ++currentId, currentPrice);

            _mint(msg.sender, zeronameId);
        }
    }

    function zeronamePrice() public view returns (uint256) {
        uint256 timeSinceStart = block.timestamp - mintStart;

        unchecked {
            return getVRGDAPrice(toDaysWadUnsafe(timeSinceStart), currentId - numMintedForCommunity);
        }
    }

    function mintCommunityZeroName(uint256 numZeroName) external returns (uint256 lastMintedZeroNameId) {
        unchecked {
            uint256 newNumMintedForCommunity = numMintedForCommunity += uint128(numZeroName);

            if (newNumMintedForCommunity > ((lastMintedZeroNameId = currentId) + numZeroName) / 10) revert ReserveImbalance();

            lastMintedZeroNameId = _batchMint(community, numZeroName, lastMintedZeroNameId);

            currentId = uint128(lastMintedZeroNameId);
            emit CommunityZeroNameMinted(msg.sender, lastMintedZeroNameId, numZeroName);
        }
    }

    function tokenURI(uint256 zeronameId) public view virtual override returns (string memory) {
        if (zeronameId == 0 || zeronameId > currentId) revert("NOT_MINTED");

        return BASE_URI;
    }
}
