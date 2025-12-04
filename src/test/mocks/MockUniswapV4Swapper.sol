    // SPDX-License-Identifier: GPL-3.0
    pragma solidity >=0.8.18;

    import {UniswapV4Swapper} from "../../swappers/UniswapV4Swapper.sol";
    import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";
    import {IHooks} from "../../interfaces/Uniswap/V4/types/PoolKey.sol";
    import {Currency} from "../../interfaces/Uniswap/V4/types/Currency.sol";

    contract MockUniswapV4Swapper is BaseStrategy, UniswapV4Swapper {
        constructor(address _asset) BaseStrategy(_asset, "Mock Uni V4") {}

        function _deployFunds(uint256) internal override {}

        function _freeFunds(uint256) internal override {}

        function _harvestAndReport()
            internal
            override
            returns (uint256 _totalAssets)
        {
            _totalAssets = asset.balanceOf(address(this));
        }

        function setMinAmountToSell(uint256 _minAmountToSell) external {
            minAmountToSell = _minAmountToSell;
        }

        function setUniPoolInfo(
            address _token0,
            address _token1,
            uint24 _fee,
            int24 _tickSpacing,
            IHooks _hooks,
            bytes memory _hookData
        ) external virtual {
            _setUniPoolInfo(_token0, _token1, _fee, _tickSpacing, _hooks, _hookData);
        }

        function setRouter(address _router) external {
            router = _router;
        }

        function setBase(address _base) external {
            base = _base;
        }

        function setUniFees(
            address _token0,
            address _token1,
            uint24 _fee
        ) external {
            _setUniFees(_token0, _token1, _fee);
        }

        function swapFrom(
            address _from,
            address _to,
            uint256 _amountIn,
            uint256 _minAmountOut
        ) external returns (uint256) {
            return _swapFrom(_from, _to, _amountIn, _minAmountOut);
        }

        function swapTo(
            address _from,
            address _to,
            uint256 _amountTo,
            uint256 _maxAmountFrom
        ) external returns (uint256) {
            return _swapTo(_from, _to, _amountTo, _maxAmountFrom);
        }
    }

    import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";
    import {IUniswapV4Swapper} from "../../swappers/interfaces/IUniswapV4Swapper.sol";

    interface IMockUniswapV4Swapper is IStrategy, IUniswapV4Swapper {
        function setMinAmountToSell(uint256 _minAmountToSell) external;

        function setRouter(address _router) external;

        function setBase(address _base) external;

        function swapTo(
            address _from,
            address _to,
            uint256 _amountTo,
            uint256 _maxAmountFrom
        ) external returns (uint256);

        function setUniPoolInfo(
            address _token0,
            address _token1,
            uint24 _fee,
            int24 _tickSpacing,
            IHooks _hooks,
            bytes memory _hookData
        ) external;

        function swapFrom(
            address _from,
            address _to,
            uint256 _amountIn,
            uint256 _minAmountOut
        ) external returns (uint256);

        function setUniFees(address _token0, address _token1, uint24 _fee) external;
    }
