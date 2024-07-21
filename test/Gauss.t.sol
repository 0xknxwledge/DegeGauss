// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "abdk-libraries-solidity/ABDKMathQuad.sol";
import "forge-std/Test.sol";
import "../src/DegeGauss.sol";

contract DegeGaussTest is Test {
    using DegeGauss for int256;

    function testCDFAccuracy() public {
        // Test cases
        int256[] memory zValues = new int256[](15);
        zValues[0] = -1e23;
        zValues[1] = -5e22;
        zValues[2] = -1e22;
        zValues[3] = -5e21;
        zValues[4] = -1e21;
        zValues[5] = -2e18;
        zValues[6] = -1e18;
        zValues[7] = 0;
        zValues[8] = 1e18;
        zValues[9] = 2e18;
        zValues[10] = 1e21;
        zValues[11] = 5e21;
        zValues[12] = 1e22;
        zValues[13] = 5e22;
        zValues[14] = 1e23;
        
        for (uint i = 0; i < zValues.length; i++) {
            int256 z = zValues[i];
            uint256 solidityResult = DegeGauss.cdf(z, 0, 1e18);
            
            string memory jsCode = string(abi.encodePacked(
                getGaussianJs(),
                vm.toString(int(z)),
                ")));"
            ));

            string[] memory inputs = new string[](3);
            inputs[0] = "node";
            inputs[1] = "-e";
            inputs[2] = jsCode;

            bytes memory jsResult = vm.ffi(inputs);
            uint256 jsResultParsed = parseJsonResult(string(jsResult));

            // Calculate the difference
            uint256 diff = solidityResult >= jsResultParsed ? 
                solidityResult - jsResultParsed : 
                jsResultParsed - solidityResult;
            
            // Log the results
            console.log("z (in 18 decimal precision):", z);
            console.log("Solidity result:", solidityResult);
            console.log("JS result:", jsResultParsed);
            console.log("Difference:", diff);
            console.log("---");

            // Assert that the difference is less than 1e10 (1e-8 in our fixed-point representation)
            assertLe(diff, 1e10, "CDF approximation differs by more than 1e-8");
        }
    }

    // Modified slightly by adding x/1e18 so we can normalize in JS and not lose precision
    // CHANGE 'const g = gaussian(mu,sigma)' IF TESTING OTHER PARAMETERIZATIONS!!!
    function getGaussianJs() internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "const erfc=function(x){const z=Math.abs(x),t=1/(1+z/2),r=t*Math.exp(-z*z-1.26551223+t*(1.00002368+t*(0.37409196+t*(0.09678418+t*(-0.18628806+t*(0.27886807+t*(-1.13520398+t*(1.48851587+t*(-0.82215223+t*0.17087277)))))))));return x>=0?r:2-r};",
                "const Gaussian=function(mean,variance){this.mean=mean;this.variance=variance;this.standardDeviation=Math.sqrt(variance)};",
                "Gaussian.prototype.cdf=function(x){return 0.5*erfc(-((x/1e18)-this.mean)/(this.standardDeviation*Math.sqrt(2)))};",
                "const gaussian=function(mean,variance){return new Gaussian(mean,variance)};",
                "const g=gaussian(0,1);",
                "console.log(JSON.stringify(g.cdf("
            )
        );  
    }


    function parseJsonResult(string memory result) internal pure returns (uint256) {
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