// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

import {Setup, ERC20, IStrategy} from "./utils/Setup.sol";

import {MockUniswapV4Swapper, IMockUniswapV4Swapper} from "./mocks/MockUniswapV4Swapper.sol";
import {IHooks} from "../interfaces/Uniswap/V4/types/PoolKey.sol";

contract UniswapV4SwapperTest is Setup {
    IMockUniswapV4Swapper public uniV4Swapper;

    ERC20 public weth;

    uint256 public minWethAmount = 1e10;
    uint256 public maxWethAmount = 1e20;

    function setUp() public override {
        super.setUp();

        weth = ERC20(tokenAddrs["WETH"]);

        uniV4Swapper = IMockUniswapV4Swapper(
            address(new MockUniswapV4Swapper(address(asset)))
        );

        uniV4Swapper.setKeeper(keeper);
        uniV4Swapper.setPerformanceFeeRecipient(performanceFeeRecipient);
        uniV4Swapper.setPendingManagement(management);
        // Accept management.
        vm.prank(management);
        uniV4Swapper.acceptManagement();        
    }

    function test_swapFrom_assetToWethV4(uint256 amount) public {
        vm.assume(amount >= minFuzzAmount && amount <= maxFuzzAmount);

        vm.startPrank(management);
        if (address(asset) == tokenAddrs["USDC"]) {
            uniV4Swapper.setUniPoolInfo(address(weth), tokenAddrs["USDC"], 3000, 60, IHooks(address(0)), new bytes(0));
        }
        else if (address(asset) == tokenAddrs["USDT"]) {
            uniV4Swapper.setUniPoolInfo(address(weth), tokenAddrs["USDT"], 500, 10, IHooks(address(0)), new bytes(0));
        }
        else {
            return;
        }
        vm.stopPrank();

        // Send some asset to the contract
        airdrop(asset, address(uniV4Swapper), amount);

        // Assert asset balance in the contract is equal to the transferred amount
        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert WETH balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);

        // Perform swap from asset to WETH
        uint256 amountOut = uniV4Swapper.swapFrom(
            address(asset),
            address(weth),
            amount,
            0
        );

        // Assert asset balance in the contract is 0
        // assertEq(asset.balanceOf(address(uniV4Swapper)), 0);
        // Assert WETH balance in the contract is greater than 0
        // assertGt(weth.balanceOf(address(uniV4Swapper)), 0);
        // Assert WETH balance in the contract is equal to the return value of the swap transaction
        // assertEq(weth.balanceOf(address(uniV4Swapper)), amountOut);
    }

    function test_swapFrom_wethToAsset(uint256 amount) public {
        vm.assume(amount >= minWethAmount && amount <= maxWethAmount);
        // Set WETH asset fees
        vm.prank(management);
        uniV4Swapper.setUniFees(address(weth), address(asset), 500);

        // Send some WETH to the contract
        airdrop(weth, address(uniV4Swapper), amount);

        // Assert WETH balance in the contract is equal to weth_amount
        assertEq(weth.balanceOf(address(uniV4Swapper)), amount);
        // Assert asset balance in the contract is 0
        assertEq(asset.balanceOf(address(uniV4Swapper)), 0);

        // Perform swap from WETH to asset
        uint256 amountOut = uniV4Swapper.swapFrom(
            address(weth),
            address(asset),
            amount,
            0
        );

        // Assert WETH balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);
        // Assert asset balance in the contract is greater than 0
        assertGt(asset.balanceOf(address(uniV4Swapper)), 0);
        // Assert asset balance in the contract is equal to the return value of the swap transaction
        assertEq(asset.balanceOf(address(uniV4Swapper)), amountOut);
    }

    function test_swapTo_wethFromAsset(uint256 amount) public {
        vm.assume(amount >= minFuzzAmount && amount <= maxFuzzAmount);
        // Set WETH asset fees
        vm.prank(management);
        uniV4Swapper.setUniFees(address(weth), address(asset), 500);

        // Send some asset to the contract
        airdrop(asset, address(uniV4Swapper), amount);

        // Assert asset balance in the contract is equal to amount
        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert WETH balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);

        uint256 toGet = (amount * 1e12) / 10_000;

        // Perform swap from asset to WETH
        uint256 amountIn = uniV4Swapper.swapTo(
            address(asset),
            address(weth),
            toGet,
            amount
        );

        // Assert asset balance in the contract is less than amount
        assertLt(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert WETH balance in the contract is equal to to_get
        assertEq(weth.balanceOf(address(uniV4Swapper)), toGet);
        // Assert the difference between amount and asset balance in the contract is equal to the return value of the swap transaction
        assertEq(amount - asset.balanceOf(address(uniV4Swapper)), amountIn);
    }

    function test_swapTo_assetFromWeth(uint256 amount) public {
        vm.assume(amount >= minWethAmount && amount <= maxWethAmount);
        // Set WETH asset fees
        uniV4Swapper.setUniFees(address(weth), address(asset), 500);

        // Send some WETH to the contract
        airdrop(weth, address(uniV4Swapper), amount);

        // Assert WETH balance in the contract is equal to amount
        assertEq(weth.balanceOf(address(uniV4Swapper)), amount);
        // Assert asset balance in the contract is 0
        assertEq(asset.balanceOf(address(uniV4Swapper)), 0);

        uint256 toGet = (amount * 1_000) / 1e12;

        // Perform swap from WETH to asset
        uint256 amountIn = uniV4Swapper.swapTo(
            address(weth),
            address(asset),
            toGet,
            amount
        );

        // Assert WETH balance in the contract is less than weth_amount
        assertLt(weth.balanceOf(address(uniV4Swapper)), amount);
        // Assert asset balance in the contract is equal to to_get
        assertEq(asset.balanceOf(address(uniV4Swapper)), toGet);
        // Assert the difference between weth_amount and WETH balance in the contract is equal to the return value of the swap transaction
        assertEq(amount - weth.balanceOf(address(uniV4Swapper)), amountIn);
    }

    function test_swapFrom_multiHop(uint256 amount) public {
        // Need to make sure we are getting enough DAI to be non 0 USDC.
        vm.assume(amount >= minFuzzAmount && amount <= maxFuzzAmount);
        ERC20 swapTo = ERC20(tokenAddrs["USDC"]);
        // Set fees for weth and asset
        uniV4Swapper.setUniFees(address(weth), address(asset), 500);
        uniV4Swapper.setUniFees(address(weth), address(swapTo), 500);

        // Send some asset to the contract
        airdrop(asset, address(uniV4Swapper), amount);

        // Assert asset balance in the contract is equal to amount
        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);
        // Assert swap_to balance in the contract is 0
        assertEq(swapTo.balanceOf(address(uniV4Swapper)), 0);

        // Perform swap from asset to swap_to
        uint256 amountOut = uniV4Swapper.swapFrom(
            address(asset),
            address(swapTo),
            amount,
            0
        );

        // Assert asset balance in the contract is 0
        assertEq(asset.balanceOf(address(uniV4Swapper)), 0);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);
        // Assert swap_to balance in the contract is greater than 0
        assertGt(swapTo.balanceOf(address(uniV4Swapper)), 0);
        // Assert swap_to balance in the contract is equal to the return value of the swap transaction
        assertEq(swapTo.balanceOf(address(uniV4Swapper)), amountOut);
    }

    function test_swapTo_multiHop(uint256 amount) public {
        // Need to make sure we are getting enough DAI to be non 0 USDC.
        vm.assume(amount >= minFuzzAmount && amount <= maxFuzzAmount);

        ERC20 swapTo = ERC20(tokenAddrs["USDC"]);
        // Set fees for weth and asset
        uniV4Swapper.setUniFees(address(weth), address(asset), 500);
        uniV4Swapper.setUniFees(address(weth), address(swapTo), 500);

        // Send some asset to the contract
        airdrop(asset, address(uniV4Swapper), amount);

        // Assert asset balance in the contract is equal to amount
        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);
        // Assert swap_to balance in the contract is 0
        assertEq(swapTo.balanceOf(address(uniV4Swapper)), 0);

        // Define the desired amount to receive
        uint256 toGet = amount / 10;

        // Perform swap from asset to swap_to
        uint256 amountIn = uniV4Swapper.swapTo(
            address(asset),
            address(swapTo),
            toGet,
            amount
        );

        // Assert asset balance in the contract is less than amount
        assertLt(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert swap_to balance in the contract is equal to to_get
        assertEq(swapTo.balanceOf(address(uniV4Swapper)), toGet);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);
        // Assert the received amount is equal to the return value of the swap transaction
        assertEq(amount - asset.balanceOf(address(uniV4Swapper)), amountIn);
    }

    function test_swapFrom_minOutReverts(uint256 amount) public {
        vm.assume(amount >= minFuzzAmount && amount <= maxFuzzAmount);
        // Set fees for weth and asset
        uniV4Swapper.setUniFees(address(weth), address(asset), 500);

        // Send some asset to the contract
        airdrop(asset, address(uniV4Swapper), amount);

        // Assert asset balance in the contract is equal to amount
        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);

        // Define the minimum amount of WETH to receive
        uint256 minOut = amount * 1e12;

        // Perform swap from asset to WETH with minimum output requirement
        vm.expectRevert();
        uniV4Swapper.swapFrom(address(asset), address(weth), amount, minOut);

        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);
    }

    function test_swapTo_maxIn_reverts(uint256 amount) public {
        vm.assume(amount >= minFuzzAmount && amount <= maxFuzzAmount);
        // Set fees for weth and asset
        uniV4Swapper.setUniFees(address(weth), address(asset), 500);

        // Send some asset to the contract
        airdrop(asset, address(uniV4Swapper), amount);

        // Assert asset balance in the contract is equal to amount
        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);

        // Define the amount of WETH to receive and the maximum amount of asset to swap
        uint256 to_get = 1e16;
        uint256 max_from = 1;

        // Perform swap from asset to WETH with specified output and maximum input
        vm.expectRevert();
        uniV4Swapper.swapTo(address(asset), address(weth), to_get, max_from);

        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);
    }

    function test_badRouter_reverts(uint256 amount) public {
        vm.assume(amount >= minFuzzAmount && amount <= maxFuzzAmount);

        // Set fees for weth and asset
        uniV4Swapper.setUniFees(address(weth), address(asset), 500);

        // Set the router address
        uniV4Swapper.setRouter(management);

        // Assert the router address is set correctly
        assertEq(uniV4Swapper.router(), management);

        // Send some asset to the contract
        airdrop(asset, address(uniV4Swapper), amount);

        // Assert asset balance in the contract is equal to amount
        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);

        // Attempt to perform swap from asset to WETH
        vm.expectRevert();
        uniV4Swapper.swapFrom(address(asset), address(weth), amount, 0);

        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);
    }

    function test_badBase_reverts(uint256 amount) public {
        vm.assume(amount >= minFuzzAmount && amount <= maxFuzzAmount);
        // Set fees for weth and asset
        uniV4Swapper.setUniFees(address(weth), address(asset), 500);

        // Set the base address
        uniV4Swapper.setBase(management);

        // Assert the base address is set correctly
        assertEq(uniV4Swapper.base(), management);

        // Send some asset to the contract
        airdrop(asset, address(uniV4Swapper), amount);

        // Assert asset balance in the contract is equal to amount
        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);

        // Attempt to perform swap from asset to WETH
        vm.expectRevert();
        uniV4Swapper.swapFrom(address(asset), address(weth), amount, 0);

        assertEq(asset.balanceOf(address(uniV4Swapper)), amount);
        // Assert weth balance in the contract is 0
        assertEq(weth.balanceOf(address(uniV4Swapper)), 0);
    }
}
