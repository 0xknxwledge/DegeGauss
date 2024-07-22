// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DegeGauss.sol";

contract DegeGaussTest is Test {
    using DegeGauss for int256;

    function testFuzzedCDFPrecision(int256 mu, uint256 sigma, int256 x) public 
    {
        // Bound the input parameters according to the specification
        mu = bound(mu, -1e20, 1e20);
        sigma = bound(sigma, 1, 1e19); 
        x = bound(x, -1e23, 1e23);

        // Measure gas consumption
        uint256 gasBefore = gasleft();

        // Calculate CDF using Solidity implementation
        uint256 solidityResult = DegeGauss.cdf(x, mu, sigma);

        // Calculate gas consumed
        uint256 gasConsumed = gasBefore - gasleft();

        // Prepare JavaScript code for comparison
        // Modified to accept standard deviation and return 0 for values that cannot be converted to 18 fixed point precision 
        string memory jsCode = string(abi.encodePacked(
            "const erfc=function(x){const z=Math.abs(x),t=1/(1+z/2),r=t*Math.exp(-z*z-1.26551223+t*(1.00002368+t*(0.37409196+t*(0.09678418+t*(-0.18628806+t*(0.27886807+t*(-1.13520398+t*(1.48851587+t*(-0.82215223+t*0.17087277)))))))));return x>=0?r:2-r};",
            "const Gaussian=function(mean,standardDeviation){this.mean=mean;this.standardDeviation=standardDeviation};",
            "Gaussian.prototype.cdf=function(x){return 0.5*erfc(-((x)-this.mean)/(this.standardDeviation*Math.sqrt(2)))};",
            "const gaussian=function(mean,standardDeviation){return new Gaussian(mean,standardDeviation)};",
            "const g=gaussian(",
            vm.toString(mu),
            ",",
            vm.toString(sigma),
            ");",
            "const result = g.cdf(",
            vm.toString(x),
            ");",
            "const fixedPointResult = result < 1e-18 ? 0 : (result >= 1 ? 1 : result);",
            "console.log(JSON.stringify(fixedPointResult));"
        ));

        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "-e";
        inputs[2] = jsCode;
        uint256 jsResultParsed = parseJsonResult(string(vm.ffi(inputs)));

        // Calculate the absolute error
        uint256 diff = solidityResult >= jsResultParsed ? 
            solidityResult - jsResultParsed : 
            jsResultParsed - solidityResult;
        
        // Log results
        console.log("x:", x);
        console.log("mu:", mu);
        console.log("sigma:", sigma);
        console.log("Solidity result:", solidityResult);
        console.log("JS result:", jsResultParsed);
        console.log("Absolute Error:", diff);
        console.log("Gas consumed:", gasConsumed);
        console.log("---");

        // Assert that the difference is less than 1e10 (1e-8 in our fixed-point representation)
        assertLe(diff, 1e10, "CDF approximation differs by more than 1e-8");

    }

    function parseJsonResult(string memory result) internal pure returns (uint256) 
    {
        bytes memory resultBytes = bytes(result);
        uint256 value = 0;
        uint256 decimalPlace = 0;
        bool decimalFound = false;
        uint256 digitCount = 0;
        int256 exponent = 0;
        bool negativeExponent = false;
        bool exponentFound = false;

        for (uint i = 0; i < resultBytes.length; i++) {
            if (resultBytes[i] >= bytes1('0') && resultBytes[i] <= bytes1('9')) {
                uint8 digit = uint8(resultBytes[i]) - uint8(bytes1('0'));
                if (exponentFound) {
                    exponent = exponent * 10 + int(uint256(digit));
                } else {
                    value = value * 10 + digit;
                    digitCount++;
                    if (decimalFound) {
                        decimalPlace++;
                    }
                }
            } else if (resultBytes[i] == '.') {
                decimalFound = true;
            } else if (resultBytes[i] == 'e' || resultBytes[i] == 'E') {
                exponentFound = true;
            } else if (exponentFound && resultBytes[i] == '-') {
                negativeExponent = true;
            }
        }

        // Adjust exponent
        if (negativeExponent) {
            exponent = -exponent;
        }

        // Adjust value based on the exponent
        if (exponent != 0) {
            if (exponent > 0) {
                value *= 10**uint256(exponent);
            } else {
                decimalPlace += uint256(-exponent);
            }
        }

        // Adjust to 18 decimal places
        if (decimalPlace < 18) {
            value *= 10**(18 - decimalPlace);
        } else if (decimalPlace > 18) {
            value /= 10**(decimalPlace - 18);
        }

        return value;
    }






}