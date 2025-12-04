// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISwapRouter} from "../interfaces/Uniswap/V3/ISwapRouter.sol";
import {BaseSwapper} from "./BaseSwapper.sol";

import {Commands} from "../interfaces/Uniswap/V4/libraries/Commands.sol";
import {IV4Router} from "../interfaces/Uniswap/V4/IV4Router.sol";
import {Actions} from "../interfaces/Uniswap/V4/libraries/Actions.sol";
import {PoolKey} from "../interfaces/Uniswap/V4/types/PoolKey.sol";
import {IUniversalRouter} from "../interfaces/Uniswap/V4/IUniversalRouter.sol";
import {IHooks} from "../interfaces/Uniswap/V4/types/PoolKey.sol";
import {Currency} from "../interfaces/Uniswap/V4/types/Currency.sol";
import {PathKey} from "../interfaces/Uniswap/V4/libraries/PathKey.sol";
import {IPermit2} from "../interfaces/Permit2/IPermit2.sol";

/**
 *   @title UniswapV3Swapper
 *   @author Yearn.finance
 *   @dev This is a simple contract that can be inherited by any tokenized
 *   strategy that would like to use Uniswap V3 for swaps. It hold all needed
 *   logic to perform both exact input and exact output swaps.
 *
 *   The global address variables default to the ETH mainnet addresses but
 *   remain settable by the inheriting contract to allow for customization
 *   based on needs or chain its used on.
 *
 *   The only variables that are required to be set are the specific fees
 *   for each token pair. The inheriting contract can use the {_setUniFees}
 *   function to easily set this for any token pairs needed.
 */
contract UniswapV4Swapper is BaseSwapper {
    using SafeERC20 for ERC20;
    // Defaults to WETH on mainnet.
    address public base = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Defaults to Uniswap V4 Universal router on mainnet.
    address public router = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;

    address public immutable permit2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // Fees for the Uni V4 pools. Each fee should get set each way in
    // the mapping so no matter the direction the correct fee will get
    // returned for any two tokens.
    mapping(address => mapping(address => uint24)) public uniFees;

    struct UniPoolInfo {
        Currency currency0;
        Currency currency1;
        uint24 fee;
        int24 tickSpacing;
        IHooks hooks;
        bytes hookData;
    }

    mapping(address => mapping(address => UniPoolInfo)) public uniPoolInfos;

    /**
     * @dev All fess will default to 0 on creation. A strategist will need
     * To set the mapping for the tokens expected to swap. This function
     * is to help set the mapping. It can be called internally during
     * initialization, through permissioned functions etc.
     */
    function _setUniFees(
        address _token0,
        address _token1,
        uint24 _fee
    ) internal virtual {
        uniFees[_token0][_token1] = _fee;
        uniFees[_token1][_token0] = _fee;
    }

    function _setUniPoolInfo(
        address _token0,
        address _token1,
        uint24 _fee,
        int24 _tickSpacing,
        IHooks _hooks,
        bytes memory _hookData
    ) internal virtual {
        if (_token0 < _token1) {
            uniPoolInfos[_token0][_token1] = UniPoolInfo(
                Currency.wrap(_token0),
                Currency.wrap(_token1),
                _fee,
                _tickSpacing,
                _hooks,
                _hookData
            );
            uniPoolInfos[_token1][_token0] = UniPoolInfo(
                Currency.wrap(_token0),
                Currency.wrap(_token1),
                _fee,
                _tickSpacing,
                _hooks,
                _hookData
            );
        } else {
            uniPoolInfos[_token1][_token0] = UniPoolInfo(
                Currency.wrap(_token1),
                Currency.wrap(_token0),
                _fee,
                _tickSpacing,
                _hooks,
                _hookData
            );
            uniPoolInfos[_token0][_token1] = UniPoolInfo(
                Currency.wrap(_token1),
                Currency.wrap(_token0),
                _fee,
                _tickSpacing,
                _hooks,
                _hookData
            );
        }
    }

    /**
     * @dev Used to swap a specific amount of `_from` to `_to`.
     * This will check and handle all allowances as well as not swapping
     * unless `_amountIn` is greater than the set `_minAmountOut`
     *
     * If one of the tokens matches with the `base` token it will do only
     * one jump, otherwise will do two jumps.
     *
     * The corresponding uniFees for each token pair will need to be set
     * other wise this function will revert.
     *
     * @param _from The token we are swapping from.
     * @param _to The token we are swapping to.
     * @param _amountIn The amount of `_from` we will swap.
     * @param _minAmountOut The min of `_to` to get out.
     * @return _amountOut The actual amount of `_to` that was swapped to
     */
    function _swapFrom(
        address _from,
        address _to,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) internal virtual returns (uint256 _amountOut) {
        if (_amountIn != 0 && _amountIn >= minAmountToSell) {
            _checkAllowance(router, _from, _amountIn);
            if (_from == base || _to == base) {
                UniPoolInfo memory info = uniPoolInfos[_from][_to];
                (
                    bytes[] memory inputs,
                    bytes memory commands
                ) = _buildExactInputSingleInputs(
                        info,
                        _from,
                        _to,
                        _amountIn,
                        _minAmountOut
                    );
                _amountOut = ERC20(_to).balanceOf(address(this));
                IUniversalRouter(router).execute(
                    commands,
                    inputs,
                    block.timestamp + 20
                );
                _amountOut = ERC20(_to).balanceOf(address(this)) - _amountOut;
            } else {
                UniPoolInfo memory infoBase = uniPoolInfos[_from][base];
                UniPoolInfo memory infoTo = uniPoolInfos[base][_to];
                (
                    bytes[] memory inputs,
                    bytes memory commands
                ) = _buildExactInputParams(
                        infoBase,
                        infoTo,
                        _from,
                        _to,
                        _amountIn,
                        _minAmountOut
                    );
                _amountOut = ERC20(_to).balanceOf(address(this));
                IUniversalRouter(router).execute(
                    commands,
                    inputs,
                    block.timestamp + 20
                );
                _amountOut = ERC20(_to).balanceOf(address(this)) - _amountOut;
            }
        }
    }

    /**
     * @dev Used to swap a specific amount of `_to` from `_from` unless
     * it takes more than `_maxAmountFrom`.
     *
     * This will check and handle all allowances as well as not swapping
     * unless `_maxAmountFrom` is greater than the set `minAmountToSell`
     *
     * If one of the tokens matches with the `base` token it will do only
     * one jump, otherwise will do two jumps.
     *
     * The corresponding uniFees for each token pair will need to be set
     * other wise this function will revert.
     *
     * @param _from The token we are swapping from.
     * @param _to The token we are swapping to.
     * @param _amountTo The amount of `_to` we need out.
     * @param _maxAmountFrom The max of `_from` we will swap.
     * @return _amountIn The actual amount of `_from` swapped.
     */
    function _swapTo(
        address _from,
        address _to,
        uint256 _amountTo,
        uint256 _maxAmountFrom
    ) internal virtual returns (uint256 _amountIn) {
        if (_maxAmountFrom != 0 && _maxAmountFrom >= minAmountToSell) {
            _checkAllowance(router, _from, _maxAmountFrom);
            if (_from == base || _to == base) {
                ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
                    .ExactOutputSingleParams(
                        _from, // tokenIn
                        _to, // tokenOut
                        uniFees[_from][_to], // from-to fee
                        address(this), // recipient
                        block.timestamp, // deadline
                        _amountTo, // amountOut
                        _maxAmountFrom, // maxAmountIn
                        0 // sqrtPriceLimitX96
                    );

                _amountIn = ISwapRouter(router).exactOutputSingle(params);
            } else {
                bytes memory path = abi.encodePacked(
                    _to,
                    uniFees[base][_to], // base-to fee
                    base,
                    uniFees[_from][base], // from-base fee
                    _from
                );

                _amountIn = ISwapRouter(router).exactOutput(
                    ISwapRouter.ExactOutputParams(
                        path,
                        address(this),
                        block.timestamp,
                        _amountTo, // How much we want out
                        _maxAmountFrom
                    )
                );
            }
        }
    }

    /**
     * @dev Internal safe function to make sure the contract you want to
     * interact with has enough allowance to pull the desired tokens.
     *
     * @param _contract The address of the contract that will move the token.
     * @param _token The ERC-20 token that will be getting spent.
     * @param _amount The amount of `_token` to be spent.
     */
    function _checkAllowance(
        address _contract,
        address _token,
        uint256 _amount
    ) internal virtual {
        ERC20(_token).forceApprove(permit2, type(uint256).max);
        IPermit2(permit2).approve(
            _token,
            _contract,
            uint160(_amount),
            uint48(block.timestamp + 20)
        );
    }

    function _buildExactInputParams(
        UniPoolInfo memory infoBase,
        UniPoolInfo memory infoTo,
        address _from,
        address _to,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) internal view returns (bytes[] memory, bytes memory) {
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        // Prepare parameters for each action
        PathKey[] memory path = new PathKey[](2);
        path[0] = PathKey(
            Currency.wrap(base),
            infoBase.fee,
            infoBase.tickSpacing,
            infoBase.hooks,
            infoBase.hookData
        );
        path[1] = PathKey(
            Currency.wrap(_to),
            infoTo.fee,
            infoTo.tickSpacing,
            infoTo.hooks,
            infoTo.hookData
        );
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputParams(
                Currency.wrap(_from),
                path,
                new uint256[](0),
                uint128(_amountIn),
                uint128(_minAmountOut)
            )
        );
        params[1] = abi.encode(Currency.wrap(_from), _amountIn);
        params[2] = abi.encode(Currency.wrap(_to), _minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        return (inputs, commands);
    }

    function _buildExactInputSingleInputs(
        UniPoolInfo memory info,
        address _from,
        address _to,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) internal view returns (bytes[] memory, bytes memory) {
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: PoolKey(
                    info.currency0,
                    info.currency1,
                    info.fee,
                    info.tickSpacing,
                    info.hooks
                ),
                zeroForOne: _from < _to ? true : false,
                amountIn: uint128(_amountIn),
                amountOutMinimum: uint128(_minAmountOut),
                hookData: info.hookData
            })
        );
        params[1] = abi.encode(info.currency0, _amountIn);
        params[2] = abi.encode(info.currency1, _minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        return (inputs, commands);
    }

    function swapExactInputSingle(
        PoolKey calldata key,
        uint128 amountIn,
        uint128 minAmountOut
    ) external returns (uint256 amountOut) {
        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(key.currency0, amountIn);
        params[2] = abi.encode(key.currency1, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        uint256 deadline = block.timestamp + 20;
        IUniversalRouter(router).execute(commands, inputs, deadline);

        // Verify and return the output amount
        amountOut = key.currency1.balanceOf(address(this));
        require(amountOut >= minAmountOut, "Insufficient output amount");
        return amountOut;
    }
}
