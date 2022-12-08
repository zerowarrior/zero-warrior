// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

abstract contract WarriorERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    string public name;

    string public symbol;

    function tokenURI(uint256 id) external view virtual returns (string memory);

    struct WarriorData {
        address owner;
        uint64 idx;
        uint32 emissionMultiple;
    }

    mapping(uint256 => WarriorData) public getWarriorData;

    struct UserData {
        uint32 warriorOwned;
        uint32 emissionMultiple;
        uint128 lastBalance;
        uint64 lastTimestamp;
    }

    mapping(address => UserData) public getUserData;

    function ownerOf(uint256 id) external view returns (address owner) {
        require((owner = getWarriorData[id].owner) != address(0), "NOT_MINTED");
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");

        return getUserData[owner].warriorOwned;
    }

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function approve(address spender, uint256 id) external {
        address owner = getWarriorData[id].owner;

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) external {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) external {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || 
            interfaceId == 0x80ac58cd || 
            interfaceId == 0x5b5e139f;
    }

    function _mint(address to, uint256 id) internal {
        unchecked {
            ++getUserData[to].warriorOwned;
        }

        getWarriorData[id].owner = to;

        emit Transfer(address(0), to, id);
    }

    function _batchMint(
        address to,
        uint256 amount,
        uint256 lastMintedId
    ) internal returns (uint256) {
        unchecked {
            getUserData[to].warriorOwned += uint32(amount);

            for (uint256 i = 0; i < amount; ++i) {
                getWarriorData[++lastMintedId].owner = to;

                emit Transfer(address(0), to, lastMintedId);
            }
        }

        return lastMintedId;
    }
}
