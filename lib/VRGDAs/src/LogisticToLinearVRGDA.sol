// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {unsafeWadDiv} from "solmate/utils/SignedWadMath.sol";

import {VRGDA} from "./VRGDA.sol";
import {LogisticVRGDA} from "./LogisticVRGDA.sol";

abstract contract LogisticToLinearVRGDA is LogisticVRGDA {
    int256 internal immutable soldBySwitch;

    int256 internal immutable switchTime;

    int256 internal immutable perTimeUnit;

    constructor(
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _logisticAsymptote,
        int256 _timeScale,
        int256 _soldBySwitch,
        int256 _switchTime,
        int256 _perTimeUnit
    ) LogisticVRGDA(_targetPrice, _priceDecayPercent, _logisticAsymptote, _timeScale) {
        soldBySwitch = _soldBySwitch;

        switchTime = _switchTime;

        perTimeUnit = _perTimeUnit;
    }

    function getTargetSaleTime(int256 sold) public view virtual override returns (int256) {
        if (sold < soldBySwitch) return LogisticVRGDA.getTargetSaleTime(sold);

        unchecked {
            return unsafeWadDiv(sold - soldBySwitch, perTimeUnit) + switchTime;
        }
    }
}
