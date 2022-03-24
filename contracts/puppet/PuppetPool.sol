pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../DamnValuableToken.sol";

contract PuppetPool is ReentrancyGuard {

    using SafeMath for uint256;
    using Address for address payable;

    address public uniswapOracle;
    mapping(address => uint256) public deposits;
    DamnValuableToken public token;

    constructor (address tokenAddress, address uniswapOracleAddress) public {
        token = DamnValuableToken(tokenAddress);
        uniswapOracle = uniswapOracleAddress;
    }

    // Allows borrowing `borrowAmount` of tokens by first depositing two times their value in ETH
    function borrow(uint256 borrowAmount) public payable nonReentrant {
        uint256 amountToDeposit = msg.value;

        /**+-Ir Order to Steal all the DVTokens from this LendingPool, we will Manipulate the Oracle
        Price to set the Token Price to 0 and then Borrow all the Tokens inside this S.C. without
        sending any ETH as collateral. We can set the Token Price to 0 by Manipulating the Balance
        in the UniSwapV1 Exchange:_
        +-Because Divison by UINTs round down to 0, if we can send mor DVTokens into UniSwapV1 S.C.
        than the amount of ETH that is locked there, then the OracleTokenPrice will be 0.
        .*/
        uint256 tokenPriceInWei = computeOraclePrice();
        uint256 depositRequired = borrowAmount.mul(tokenPriceInWei) * 2;

        require(amountToDeposit >= depositRequired, "Not depositing enough collateral");
        if (amountToDeposit > depositRequired) {
            uint256 amountToReturn = amountToDeposit - depositRequired;
            amountToDeposit -= amountToReturn;
            msg.sender.sendValue(amountToReturn);
        }        

        deposits[msg.sender] += amountToDeposit;

        // Fails if the pool doesn't have enough tokens in liquidity
        require(token.transfer(msg.sender, borrowAmount), "Transfer failed");
    }

    function computeOraclePrice() public view returns (uint256) {
        return uniswapOracle.balance.div(token.balanceOf(uniswapOracle));
    }

     /**
     ... functions to deposit, redeem, repay, calculate interest, and so on ...
     */

}