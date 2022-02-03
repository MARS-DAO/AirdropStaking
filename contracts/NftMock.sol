// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./lib/ERC1155.sol";
import "./lib/Ownable.sol";


contract MarsDAOStakingNFT is Ownable, ERC1155("") {

    function mint(address to,uint256 id,uint256 amount) external onlyOwner{
        _mint(to, id, amount, "");
    }

    function setURI(string memory newuri) external onlyOwner{
        _setURI(newuri);
    }

    function airDrop(address[] memory recipients,
                        uint256 id,
                        uint256 amount)external onlyOwner returns (uint256,address){
        
        uint256 length = recipients.length;
        uint256 i = 0;
        
        do{
            _mint(recipients[i], id, amount, "");
            i++;
        }while(i < length && gasleft()>500000);

        return (i,(i>0 ? recipients[i-1]:address(0)));
    }

}