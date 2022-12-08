// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {unsafeWadDiv} from "solmate/utils/SignedWadMath.sol";

import {VRGDA} from "./VRGDA.sol";

abstract contract LinearVRGDA is VRGDA {
    int256 internal immutable perTimeUnit;

    constructor(
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) VRGDA(_targetPrice, _priceDecayPercent) {
        perTimeUnit = _perTimeUnit;
    }

    function getTargetSaleTime(int256 sold) public view virtual override returns (int256) {
        return unsafeWadDiv(sold, perTimeUnit);
    }
}
