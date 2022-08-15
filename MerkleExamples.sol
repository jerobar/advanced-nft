// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Each leaf of the tree is basically a token to be minted

contract MerkleExampleOne is ERC721 {
    bytes32 public immutable root;

    constructor(
        string memory name,
        string memory symbol,
        bytes32 merkeroot
    ) ERC721(name, symbol) {
        root = merkeroot;
    }

    function redeem(
        address account,
        uint256 tokenId,
        bytes32[] calldata proof
    ) external {
        require(
            _verify(_leaf(account, tokenId), proof),
            "invalid merkle proof"
        );
        _safeMint(account, tokenId);
    }

    function _verify(bytes32 leaf, bytes32[] memory proof)
        internal
        view
        returns (bool)
    {
        return MerkleProof.verify(proof, root, leaf);
    }

    function _leaf(address account, uint256 tokenId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(tokenId, account));
    }
}
