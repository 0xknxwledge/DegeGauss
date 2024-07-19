// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DegeGauss.sol";

contract DegeGaussTest is Test {
    using DegeGauss for int256;

    function testCDFAccuracy() public {
        // Test cases
        int256[] memory zValues = new int256[](11);
        zValues[0] =  0;
        zValues[1] = -2 * 1e18;
        zValues[2] = -1 * 1e18;
        zValues[3] = -0.5 * 1e18;
        zValues[4] = 0;
        zValues[5] = 0.5 * 1e18;
        zValues[6] = 1 * 1e18;
        zValues[7] = 2 * 1e18;
        zValues[8] = 3 * 1e18;
        zValues[9] = 4 * 1e18;
        zValues[10] = 5 * 1e18;
        
        for (uint i = 0; i < zValues.length; i++) {
            int256 z = zValues[i];
            uint256 solidityResult = DegeGauss.cdf(z, 0, 1e18);
            
            string memory jsCode = string(abi.encodePacked(
                getGaussianJs(),
                vm.toString(int(z) / 1e18),
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
            console.log("z:", z / 1e18);
            console.log("Solidity result:", solidityResult);
            console.log("JS result:", jsResultParsed);
            console.log("---");

            // Assert that the difference is less than 0.1% (1e15 in our fixed-point representation)
            assertLe(diff, 1e15, "CDF approximation differs by more than 0.1%");
        }
    }

    function getGaussianJs() internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "const erfc=function(x){const z=Math.abs(x),t=1/(1+z/2),r=t*Math.exp(-z*z-1.26551223+t*(1.00002368+t*(0.37409196+t*(0.09678418+t*(-0.18628806+t*(0.27886807+t*(-1.13520398+t*(1.48851587+t*(-0.82215223+t*0.17087277)))))))));return x>=0?r:2-r};",
                "const Gaussian=function(mean,variance){this.mean=mean;this.variance=variance;this.standardDeviation=Math.sqrt(variance)};",
                "Gaussian.prototype.cdf=function(x){return 0.5*erfc(-(x-this.mean)/(this.standardDeviation*Math.sqrt(2)))};",
                "const gaussian=function(mean,variance){return new Gaussian(mean,variance)};",
                "const g=gaussian(0,1);",
                "console.log(JSON.stringify(g.cdf("
            )
        );  
    }


    function parseJsonResult(string memory result) internal pure returns (uint256) {
        bytes memory resultBytes = bytes(result);
        uint256 value;
        uint256 decimalPlace = 0;
        bool decimalFound = false;
        
        for (uint i = 0; i < resultBytes.length; i++) {
            if (resultBytes[i] >= bytes1('0') && resultBytes[i] <= bytes1('9')) {
                value = value * 10 + uint8(resultBytes[i]) - uint8(bytes1('0'));
                if (decimalFound) {
                    decimalPlace++;
                }
            } else if (resultBytes[i] == '.') {
                decimalFound = true;
            }
        }
        
        // Adjust to 18 decimal places
        while (decimalPlace < 18) {
            value *= 10;
            decimalPlace++;
        }
        while (decimalPlace > 18) {
            value /= 10;
            decimalPlace--;
        }
        
        return value;
    }

}