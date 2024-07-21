// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "abdk-libraries-solidity/ABDKMathQuad.sol";
import "forge-std/console.sol";


/*
    Tuff
*/
library DegeGauss {
    using ABDKMathQuad for uint256;
    using ABDKMathQuad for int256;
    using ABDKMathQuad for bytes16;

    // Constants are set to 18 decimal precision, 
    uint256 internal constant WAD = 1 ether; //i.e, 1e18 == 10**18 
    uint256 internal constant HALF = .5 ether;
    uint256 internal constant TWO = 2 ether;
    uint256 internal constant RV_BOUND = 1e23; // i.e, 100000
    uint256 internal constant MU_BOUND = 1e20; // i.e, 100
    uint256 internal constant SIG_BOUND = 1e19; // i.e, 10
    uint256 internal constant SQRT_2 = 1_414213562373095048;
    int256 internal constant ERFC_A = 1_265512230000000000;
    int256 internal constant ERFC_B = 1_000023680000000000;
    int256 internal constant ERFC_C = 374091960000000000; 
    int256 internal constant ERFC_D = 96784180000000000; 
    int256 internal constant ERFC_E = -186288060000000000; 
    int256 internal constant ERFC_F = 278868070000000000; 
    int256 internal constant ERFC_G = -1_135203980000000000;
    int256 internal constant ERFC_H = 1_488515870000000000;
    int256 internal constant ERFC_I = -822152230000000000; 
    int256 internal constant ERFC_J = 170872770000000000;

    error AbsOverflow();
    error ParamOOB();

    function abs(int256 x) internal pure returns (uint256 y) 
    {
        if (x == type(int256).min) revert AbsOverflow();
        if (x < 0) {
            assembly {
                y := add(not(x), 1)
            }
        } else {
            assembly {
                y := x
            }
        }
    }

    /*
        erfc(x) =  1 - erf(x) = 2/sqrt(pi) int^{\infty}_{x}e^-t^2dt
    */
    function erfc(bytes16 x) internal pure returns (bytes16)
    {
        bytes16 one = ABDKMathQuad.fromUInt(WAD);
        // Set to 18 decimal precision
        bytes16 z = ABDKMathQuad.abs(x).mul(one);
        // Compute t = 1 / (1 + 0.5 * z)
        bytes16 t = ABDKMathQuad.fromUInt(1).div(ABDKMathQuad.fromUInt(1).add(z.div(ABDKMathQuad.fromUInt(2))));

        bytes16 k;
        bytes16 step;
        // Avoid stack overflow with separate context
        // Divide constants by 1e18 so no overflow while computations are performed
        {   
            bytes16 _t = t;
            step =ABDKMathQuad.fromInt(ERFC_F).div(one)
            .add(_t.mul(ABDKMathQuad.fromInt(ERFC_G).div(one)
            .add(_t.mul(ABDKMathQuad.fromInt(ERFC_H).div(one)
            .add(_t.mul(ABDKMathQuad.fromInt(ERFC_I).div(one)
            .add(_t.mul(ABDKMathQuad.fromInt(ERFC_J).div(one)))))))));
        }

        {
            bytes16 _t = t;
            step = _t
            .mul(ABDKMathQuad.fromInt(ERFC_B).div(one)
            .add(_t.mul(ABDKMathQuad.fromInt(ERFC_C).div(one)
            .add(_t.mul(ABDKMathQuad.fromInt(ERFC_D).div(one)
            .add(_t.mul(ABDKMathQuad.fromInt(ERFC_E).div(one)
            .add(_t.mul(step)))))))));

            k = z.mul(z)
            .neg()
            .sub(ABDKMathQuad.fromInt(ERFC_A).div(one))
            .add(step);
        }
        console.logBytes16(k);
        bytes16 exp = k.exp();
        console.logBytes16(exp);
        bytes16 r = t.mul(exp);
        console.logBytes16(r);
        return r;
    }

    function cdf(int256 x, int256 mu, uint256 sigma) internal pure returns (uint256) 
    {
        if
        (
            (abs(x) > RV_BOUND) ||
            (abs(mu) > MU_BOUND) ||
            (sigma > SIG_BOUND || sigma == 0)
        )
        {
            revert ParamOOB();
        }

        // Normalize x ~ N(0,1)
        bytes16 standardX = ABDKMathQuad.fromInt(x).sub(ABDKMathQuad.fromInt(mu))
        .div(ABDKMathQuad.fromUInt(sigma).mul(ABDKMathQuad.fromUInt(SQRT_2)));

        bytes16 erfcResult = erfc(standardX.neg());
    
        bytes16 half = ABDKMathQuad.fromUInt(HALF);
        bytes16 result;
        if (x-mu > 0) {
            // 1 - r/2
            result = ABDKMathQuad.fromUInt(WAD).sub(half.mul(erfcResult));
        } else {
            // r/2
            result = half.mul(erfcResult);
        }

        return ABDKMathQuad.toUInt(result);
    }

}