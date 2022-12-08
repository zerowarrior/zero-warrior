// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";


library LibZERO {
    using FixedPointMathLib for uint256;

    function computeZEROBalance(
        uint256 emissionMultiple,
        uint256 lastBalanceWad,
        uint256 timeElapsedWad
    ) internal pure returns (uint256) {
        unchecked {
            uint256 timeElapsedSquaredWad = timeElapsedWad.mulWadDown(timeElapsedWad);

            return lastBalanceWad +

            ((emissionMultiple * timeElapsedSquaredWad) >> 2) +

            timeElapsedWad.mulWadDown( 
               (emissionMultiple * lastBalanceWad * 1e18).sqrt()
            );
        }
    }
}
