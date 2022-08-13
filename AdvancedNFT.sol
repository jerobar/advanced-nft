// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

contract AdvancedNFT {
    // REQUIRE STATEMENTS SHOULD ONLY DEPEND ON THE STATE (except when checking input validity)

    enum Stages {
        MintsCanHappen,
        PresaleIsActive,
        PublicSaleIsActive,
        SupplyHasRunOut
    }

    Stages public stage = Stages.MintsCanHappen;

    // mapping(address => uint256) public balances; // measure gas vs. bitmap

    // e.g. atStage(Stages.AcceptingBlindedBids)
    modifier atStage(Stages stage_) {
        require(
            stage == stage_,
            "AdvancedNFT: Feature not available at this stage"
        );
        _;
    }

    function nextStage() internal {
        stage = Stages(uint(stage) + 1);
    }

    // Designated addresses may use pull patern to withdraw to arbitrary number of contributors
}

// Implements a merkle tree airdrop where addresses in the tree are allowed to mint once.
// - hint: merkle leaf should be a hash of the address and its index in the bitmap
// use bitmaps from OZ

// Use commit reveal to allocate NFT ids randomly. The reveal should be 10 blocks ahead of the commit.
// - look at cool cats NFT to see how this is done (they use chainlink, you should use commit reveal)

// Add multicall to the NFT so people can transfer several NFTs in one transaction (make sure people can’t abuse minting!)
