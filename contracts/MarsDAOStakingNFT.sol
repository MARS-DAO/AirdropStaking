// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./lib/ERC1155.sol";
import "./lib/Ownable.sol";


contract MarsDAOStakingNFT is Ownable,
    ERC1155("https://ipfs.io/ipfs/QmSg5RZQXEJUCXL2HtE18ywo2SbKkvUFydHPAFSuAt8BPy/{id}.json") {

        string public name="MarsDAO";
        string public symbol="MDAO";

    function mint(address to,uint256 id,uint256 amount) external onlyOwner{
        _mint(to, id, amount, "");
    }

    function setURI(string memory newuri) external onlyOwner{
        _setURI(newuri);
    }

    function airDrop(address[] memory recipients,
                        uint256 id,
                        uint256 amount) external onlyOwner {
        
        uint256 length = recipients.length;
        for (uint256 i = 0; i < length; ++i) {
            _mint(recipients[i], id, amount, "");
        }
    }

}