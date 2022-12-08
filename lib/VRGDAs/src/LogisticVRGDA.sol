// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {wadLn, unsafeDiv, unsafeWadDiv} from "solmate/utils/SignedWadMath.sol";

import {VRGDA} from "./VRGDA.sol";

abstract contract LogisticVRGDA is VRGDA {
    int256 internal immutable logisticLimit;

    int256 internal immutable logisticLimitDoubled;

    int256 internal immutable timeScale;

    constructor(
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _maxSellable,
        int256 _timeScale
    ) VRGDA(_targetPrice, _priceDecayPercent) {
        logisticLimit = _maxSellable + 1e18;

        logisticLimitDoubled = logisticLimit * 2e18;

        timeScale = _timeScale;
    }

    function getTargetSaleTime(int256 sold) public view virtual override returns (int256) {
        unchecked {
            return -unsafeWadDiv(wadLn(unsafeDiv(logisticLimitDoubled, sold + logisticLimit) - 1e18), timeScale);
        }
    }
}
