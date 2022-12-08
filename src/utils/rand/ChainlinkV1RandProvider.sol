// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {VRFConsumerBase} from "chainlink/v0.8/VRFConsumerBase.sol";

import {ZeroWarrior} from "../../ZeroWarrior.sol";

import {RandProvider} from "./RandProvider.sol";


contract ChainlinkV1RandProvider is RandProvider, VRFConsumerBase {
    ZeroWarrior public immutable zeroWarrior;

    bytes32 internal immutable chainlinkKeyHash;

    uint256 internal immutable chainlinkFee;

    error NotWarrior();

    constructor(
        ZeroWarrior _zeroWarrior,
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _chainlinkKeyHash,
        uint256 _chainlinkFee
    ) VRFConsumerBase(_vrfCoordinator, _linkToken) {
        zeroWarrior = _zeroWarrior;

        chainlinkKeyHash = _chainlinkKeyHash;
        chainlinkFee = _chainlinkFee;
    }

    function requestRandomBytes() external returns (bytes32 requestId) {
        if (msg.sender != address(zeroWarrior)) revert NotWarrior();

        emit RandomBytesRequested(requestId = requestRandomness(chainlinkKeyHash, chainlinkFee));
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        emit RandomBytesReturned(requestId, randomness);

        zeroWarrior.acceptRandomSeed(requestId, randomness);
    }
}
