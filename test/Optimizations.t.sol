// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

contract OptimizationsTest is DSTestPlus {
    function testFuzzCurrentIdMultipleBranchlessOptimization(uint256 swapIndex) public {

        uint256 newCurrentIdMultipleBranchless = 9;
        assembly {
            newCurrentIdMultipleBranchless := sub(sub(sub(
                newCurrentIdMultipleBranchless,
                lt(swapIndex, 7964)),
                lt(swapIndex, 5673)),
                lt(swapIndex, 3055)
            )
        }


        uint256 newCurrentIdMultipleBranched = 9;
        if (swapIndex <= 3054) newCurrentIdMultipleBranched = 6;
        else if (swapIndex <= 5672) newCurrentIdMultipleBranched = 7;
        else if (swapIndex <= 7963) newCurrentIdMultipleBranched = 8;


        assertEq(newCurrentIdMultipleBranchless, newCurrentIdMultipleBranched);
    }
}
