// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "abdk-libraries-solidity/ABDKMathQuad.sol";
import "forge-std/console.sol";

/*
    Gaussian CDF Approximation for Degens
    
    Inputs and outputs are in 18 decimal fixed point representation
    Computation done in 128-bit IEEE 754 floating point (courtesy of https://github.com/abdk-consulting/abdk-libraries-solidity/tree/master)

    Heavily Inspired by https://github.com/primitivefinance/solstat and https://github.com/errcw/gaussian

*/

library DegeGauss {
    using ABDKMathQuad for uint256;
    using ABDKMathQuad for int256;
    using ABDKMathQuad for bytes16;
    
    // Parameter bounds in 18 decimal fixed point
    uint256 internal constant RV_BOUND = 1e23; // 100000 
    uint256 internal constant MU_BOUND = 1e20; // 100
    uint256 internal constant SIG_BOUND = 1e19; // 10
    // ERFC constants  in 128 bit IEEE 754 
    bytes16 internal constant LIL_ONE = 0x3FFF0000000000000000000000000000; // 1
    bytes16 internal constant LIL_TWO = 0x40000000000000000000000000000000; // 2
    bytes16 internal constant ERFC_A = 0x3FFF43F89C0889BC56DDDD406270B87A; // 1.26551223
    bytes16 internal constant ERFC_B = 0x3FFF00018D48D35882222EA90AD0BE74; // 1.00002368
    bytes16 internal constant ERFC_C = 0x3FFD7F11F677960E9FAB009F373D58FC; // 0.37409196
    bytes16 internal constant ERFC_D = 0x3FFB8C6D917DEC3F02F527DFC2F3B010; // 0.09678418
    bytes16 internal constant ERFC_E = 0xBFFC7D84982AAEAA4CF01DB4C6C6A368; // -0.18628806
    bytes16 internal constant ERFC_F = 0x3FFD1D8F976231CE593EE09079098133; // 0.27886807
    bytes16 internal constant ERFC_G = 0xBFFF229CBA606397FFE67FA65366597B; // -1.13520398
    bytes16 internal constant ERFC_H = 0x3FFF7D0F60453A1BDAA700099021A0BA; // 1.48851587
    bytes16 internal constant ERFC_I = 0xBFFEA4F123185DEFCA52C9FC62E780D8; // -0.82215223
    bytes16 internal constant ERFC_J = 0x3FFC5DF28AF76A5A3BE0ABD1D5753CEE; // 0.17087277
    // Normalization constants in 18 decimal fixed point but stored as 128 bit IEEE 754 
    bytes16 internal constant ONE = 0x403ABC16D674EC800000000000000000; // 1e18
    bytes16 internal constant HALF = 0x4039BC16D674EC800000000000000000; // 5e17
    bytes16 internal constant SQRT_2 = 0x403B3A04BBDFDC9BE880000000000000; // sqrt(2)e18

    error AbsOverflow();
    error ParamOOB();


    function abs(int256 x) internal pure returns (uint256 y) 
    {
        if (x == type(int256).min) revert AbsOverflow();
        unchecked {
            y = x < 0 ? uint256(-x) : uint256(x);
        }
    }

    /*
        erfc(x) =  1 - erf(x) = 2/sqrt(pi) int^{\infty}_{x}e^(-t^2)dt = 2 * cdf(sqrt(2)x) - 1
    */
    function erfc(bytes16 z) internal pure returns (bytes16)
    {
        // Set to 18 decimal precision
        z = ABDKMathQuad.abs(z).mul(ONE);
        // Compute t = 1 / (1 + z/2)
        bytes16 t = LIL_ONE.div(LIL_ONE.add(z.div(LIL_TWO)));

        bytes16 k;
        bytes16 step;
        // Avoid stack overflow with separate context
        // Divide constants by 1e18 so no overflow while computations are performed
        {   
            bytes16 _t = t;
            step = ERFC_F
            .add(_t.mul(ERFC_G
            .add(_t.mul(ERFC_H
            .add(_t.mul(ERFC_I
            .add(_t.mul(ERFC_J))))))));
        }

        {
            bytes16 _t = t;
            step = _t
            .mul(ERFC_B
            .add(_t.mul(ERFC_C
            .add(_t.mul(ERFC_D
            .add(_t.mul(ERFC_E
            .add(_t.mul(step)))))))));

            k = z.mul(z)
            .neg()
            .sub(ERFC_A)
            .add(step);
        }

        bytes16 exp = k.exp();

        bytes16 r = t.mul(exp);
 
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

        // Normalize (x-mu)/sigma ~ N(0,1)
        // cdf(z) = erfc(-z/sqrt(2))
        bytes16 z = ABDKMathQuad.fromInt(x).sub(ABDKMathQuad.fromInt(mu))
        .div(ABDKMathQuad.fromUInt(sigma).mul(SQRT_2));
        bytes16 erfcResult = erfc(z.neg());
        
        // Return 1-Q(x) if centered input is right-tail of N(0,1), Q(x) if left-tail/mean
        // Q(x) = 1-cdf(x)
        return x - mu > 0 ? ABDKMathQuad.toUInt(ONE.sub(HALF.mul(erfcResult))) : ABDKMathQuad.toUInt(HALF.mul(erfcResult));
    }

}