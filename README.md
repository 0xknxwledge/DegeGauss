# DegeGauss: Gaussian CDF Optimized for Degens

## Overview
- Inputs and Outputs are in 18 decimal fixed point representation
- Parameters: x (realization), μ (mean), σ (standard deviation)
- Constraints:
  - -1e20 ≤ μ ≤ 1e20
  - 0 < σ ≤ 1e19
  - x in [-1e23, 1e23]
- High-precision computation using 128-bit IEEE 754 floating-point arithmetic and Horner's Method for a complementary
error function polynomial approximation 
- Median fuzz test consumes ~53000 gas (a little over two ETH transfers), has relative absolute error ~1e-16 compared to errcw/gaussian
- Run "forge test --match-test testFuzzedCDFPrecisionStats -vvvvv" to verify 
- TODO: Get gas consumption down while preserving precision

## Usage

```solidity
import "./DegeGauss.sol";

contract YourContract {
    using DegeGauss for int256;
    using DegeGauss for uint256;

    function computeCDF(int256 x, int256 mu, uint256 sigma) public pure returns (uint256) {
        return DegeGauss.cdf(x, mu, sigma);
    }
}
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by [primitivefinance/solstat](https://github.com/primitivefinance/solstat) and [errcw/gaussian](https://github.com/errcw/gaussian)
- Uses [ABDK Libraries for Solidity](https://github.com/abdk-consulting/abdk-libraries-solidity)
- Submission for the following 2024 Paradigm Fellowship technical question:
  - Implement a maximally optimized gaussian CDF on the EVM for arbitrary 18 decimal fixed point parameters x, μ, σ. Assume -1e20 ≤ μ ≤ 1e20 and 0 < σ ≤ 1e19. Should have an error less than 1e-8 vs errcw/gaussian for all x on the interval [-1e23, 1e23].