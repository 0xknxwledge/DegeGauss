// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

library DegeGauss {
    using FixedPointMathLib for int256;
    using FixedPointMathLib for uint256;

    // Constants are set to 18 decimal precision, 
    uint256 internal constant WAD = 1 ether; //i.e, 1e18 == 10**18 
    
    uint256 internal constant RV_BOUND = 1e23 * WAD; 
    uint256 internal constant MU_BOUND = 1e20 * WAD; 
    uint256 internal constant SIG_BOUND = 1e19 * WAD;
    uint256 internal constant RIGHT_TAIL_BOUND = 8 * WAD;

    uint256 internal constant k1 = 1595769118700000000;

    error AbsOverflow();
    error ParamOOB();

    function abs(int256 x) internal pure returns (uint256 y) 
    {
        if(x == type(int256).min) revert AbsOverflow();
        if(x < 0) 
        {
            assembly 
            {
                y := add(not(x), 1)
            }
        } 
        else 
        {
            assembly 
            {
                y := x
            }
        }
    }


    /*
    Approximation is from https://arxiv.org/pdf/2206.12601
    */
    function compute_cdf_approximation(uint256 z) internal pure returns (uint256) 
    {   

        uint256[16] memory k = [
        uint256(53736600000),
        uint256(726707690000000000),
        uint256(922900000000),
        uint256(53498000000000),
        uint256(90342000000000),
        uint256(104944800000000),
        uint256(3026361100000000),
        uint256(299472642000000),
        uint256(198173433000000),
        uint256(94285766000000),
        uint256(31366467000000),
        uint256(7152436600000),
        uint256(1095506130000),
        uint256(107995900000),
        uint256(6208087000),
        uint256(158537100)
        ];
        uint256 alpha1 = k1;
        uint256 alpha2 = 0;
        for(uint8 i = 0; i < 16; i++) {
            uint256 term = FixedPointMathLib.mulWadUp(k[i], uint256(FixedPointMathLib.powWad(int256(z), int256((i+1) * WAD))));
            if(i == 2 || i == 3 || i == 4 || i == 6 || i == 8 || i == 10 || i == 14) {
                alpha2 += term;
            } else {
                alpha1 += term;
            }
        }
        
        bool is_negative = alpha1 <= alpha2;
        uint256 alpha = is_negative ? alpha2 - alpha1 : alpha1 - alpha2;
        
        int256 exponent = int256(FixedPointMathLib.mulWadDown(z, alpha));
        
        uint256 expResult;
        if (is_negative) {
            // If alpha is negative, we need to calculate e^x directly
            expResult = uint256(FixedPointMathLib.expWad(exponent));
        } else {
            // If alpha is positive, we calculate 1/e^x
            expResult = FixedPointMathLib.divWadDown(WAD, uint256(FixedPointMathLib.expWad(exponent)));
        }
        
        return FixedPointMathLib.divWadUp(WAD, WAD + expResult);
    }

    function cdf(int256 z, int256 mu, uint256 sigma) internal pure returns (uint256) 
    {
        if
        (
            (abs(z) > RV_BOUND) ||
            (abs(mu) > MU_BOUND) ||
            (sigma > SIG_BOUND || sigma == 0)
        )
        {
            revert ParamOOB();
        }

        int256 diff = z - mu;
        if(diff == 0)
        {
            return 5e17;
        }
        bool is_negative = diff < 0;

        uint256 abs_diff = is_negative ? uint256(-diff) : uint256(diff);
        
        uint256 standardized_z = FixedPointMathLib.divWadDown(abs_diff, sigma);
        
        if(standardized_z >= RIGHT_TAIL_BOUND)
        {
            return is_negative ? 0 : WAD;
        }

        uint256 p = compute_cdf_approximation(standardized_z);
        return is_negative ? WAD - p : p;
    }

}

    