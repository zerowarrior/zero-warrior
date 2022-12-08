// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {wadExp, wadLn, wadMul, unsafeWadMul, toWadUnsafe} from "solmate/utils/SignedWadMath.sol";


abstract contract VRGDA {
    int256 public immutable targetPrice;

    int256 internal immutable decayConstant;

    constructor(int256 _targetPrice, int256 _priceDecayPercent) {
        targetPrice = _targetPrice;

        decayConstant = wadLn(1e18 - _priceDecayPercent);

        require(decayConstant < 0, "NON_NEGATIVE_DECAY_CONSTANT");
    }

    function getVRGDAPrice(int256 timeSinceStart, uint256 sold) public view virtual returns (uint256) {
        unchecked {
            return uint256(wadMul(targetPrice, wadExp(unsafeWadMul(decayConstant,
                timeSinceStart - getTargetSaleTime(toWadUnsafe(sold + 1))
            ))));
        }
    }

    function getTargetSaleTime(int256 sold) public view virtual returns (int256);
}
