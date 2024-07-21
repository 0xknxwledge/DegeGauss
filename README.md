# DegeGauss: Gaussian CDF Optimized for Degens

## Overview
- Inputs and Outputs are in 18 decimal fixed point representation
- Parameters: x (variable), μ (mean), σ (standard deviation)
- Constraints:
  - -1e20 ≤ μ ≤ 1e20
  - 0 < σ ≤ 1e19
  - x in [-1e23, 1e23]
- Error requirement: < 1e-8 vs errcw/gaussian
- High-precision and gas efficient computation using 128-bit IEEE 754 floating-point arithmetic
- Max absolute error relative to errcw/gaussian on the order of 1e-17 (check Gauss.t.sol to verify and test out other parameterizations and realizations)

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
  - Implement a maximally optimized gaussian CDF on the EVM for arbitrary 18 decimal fixed point parameters x, μ, σ. Assume -1e20 ≤ μ ≤ 1e20 and 0 < σ ≤ 1e19. Should have an error less than 1e-8 vs 