// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/Ownable.sol";
import "./lib/SafeERC20.sol";
import "./lib/IERC20.sol";

contract MarsVault is Ownable{
    using SafeERC20 for IERC20;
    
    IERC20 immutable public marsToken;

    constructor(address _marsToken) public {
        marsToken=IERC20(_marsToken);
    }

    function safeRewardsTransfer(address _to, uint256 _amount) external onlyOwner {
        uint256 marsBal = marsToken.balanceOf(address(this));
        if (_amount > marsBal) {
            marsToken.transfer(_to, marsBal);
        } else {
            marsToken.transfer(_to, _amount);
        }
    }
}