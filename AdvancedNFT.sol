// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// TODO:
// - Figure out how to automate transition to end of presale stage (timed?)

contract AdvancedNFT is ERC721 {
    using BitMaps for BitMaps.BitMap;
    using Strings for uint256;

    address[] private _contributors;

    bytes32 public immutable merkleRoot;
    BitMaps.BitMap private _presaleAllocations;
    uint256 public revealBlockNumber;
    uint256 public revealBlockhash;

    uint256 public PRICE = 0.05 ether;
    uint256 public immutable TOTAL_SUPPLY_CAP = 1000;
    uint256 public tokenIdToMint = 0;

    // Measure gas vs. bitmap (hardhat `REPORT_GAS=true` `npx hardhat test`)
    // mapping(address => uint256) public balances;

    enum Stages {
        PresaleMinting,
        Presale,
        PublicSale,
        SupplyExhausted
    }

    Stages public stage = Stages.PresaleMinting;

    modifier atStage(Stages stage_) {
        require(
            stage == stage_,
            "AdvancedNFT: Feature not available at this stage"
        );
        _;
    }

    modifier msgValueEqualsPRICE() {
        require(msg.value == PRICE, "AdvancedNFT: Invalid transaction value");
        _;
    }

    /**
     * @dev
     */
    constructor(
        string memory name,
        string memory symbol,
        bytes32 merkleRoot_,
        address[] memory contributors
    ) ERC721(name, symbol) {
        _contributors = contributors;
        merkleRoot = merkleRoot_;
    }

    /**
     * @dev Commits to basing the metadata randomization (offset) on the block
     * hash of current block number + 10.
     *
     * Requirements:
     *
     * - At stage `PresaleMinting`
     * - `revealBlockNumber` not yet set
     */
    function commit() external atStage(Stages.PresaleMinting) {
        require(revealBlockNumber == 0, "AdvancedNFT: Already committed");

        revealBlockNumber = block.number + 10;
    }

    /**
     * @dev Reveals the `metadataRandomSeed` which is used to calculate the
     * offset of a given token id relative to its URI.
     *
     * Requirements:
     *
     * - At stage `PresaleMinting`
     * - At or beyond `revealBlockNumber`
     * - `revealBlockhash` not yet set
     */
    function reveal() external atStage(Stages.PresaleMinting) {
        require(
            block.number > revealBlockNumber - 1,
            "AdvancedNFT: Cannot reveal yet"
        );
        require(revealBlockhash == 0, "AdvancedNFT: Already revealed");

        revealBlockhash = uint256(blockhash(revealBlockNumber));

        // Transition from `PresaleMinting` to `Presale`
        _nextStage();
    }

    /**
     * @dev Returns the URI of `tokenId` which is "randomized" by being offset
     * within the list of token id's as a function of `metadataRandomSeed`.
     *
     * Requirements:
     *
     * - `tokenId` has been minted
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();

        // Offset `metadataId` as a function of `revealBlockhash` value
        uint256 metadataId = (tokenId + revealBlockhash) % TOTAL_SUPPLY_CAP;

        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, metadataId.toString()))
                : "";
    }

    /**
     * @dev Allows users with presale tickets to mint one token per ticket,
     * verified by their supplied `merkleProof`.
     *
     * Requirements:
     *
     * - At stage `Presale`
     * - `msg.sender` is not contract
     * - `msg.value` == `PRICE`
     * - Caller provided valid `merkleProof`
     * - `ticketNumber` not already redeemed
     */
    function presale(uint256 ticketNumber, bytes32[] calldata merkleProof)
        external
        payable
        atStage(Stages.Presale)
        msgValueEqualsPRICE
    {
        require(
            _merkleProofVerify(
                merkleProof,
                _merkleLeaf(msg.sender, ticketNumber)
            ),
            "AdvancedNFT: Invalid merkle proof"
        );
        require(
            BitMaps.get(_presaleAllocations, ticketNumber),
            "AdvancedNFT: Ticket number already redeemed"
        );

        // Mark this `ticketNumber` as redeemed
        BitMaps.set(_presaleAllocations, ticketNumber);

        _mint(msg.sender, tokenIdToMint);
        tokenIdToMint += 1;
    }

    /**
     * @dev After the presale, allows public to mint one token at a time.
     *
     * Requirements:
     *
     * - At stage `PublicSale`
     * - `msg.value` == `PRICE`
     */
    function publicSale()
        external
        payable
        atStage(Stages.PublicSale)
        msgValueEqualsPRICE
    {
        _mint(msg.sender, tokenIdToMint);
        tokenIdToMint += 1;

        if (tokenIdToMint == TOTAL_SUPPLY_CAP) {
            // Transition from `PublicSale` to `SupplyExhausted`
            _nextStage();
        }
    }

    /**
     * @dev Allows transfer of multiple tokens in a single call.
     */
    function transferMultiple(
        address[] calldata from,
        address[] calldata to,
        uint256[] calldata tokenId
    ) external {
        require(
            from.length == to.length && to.length == tokenId.length,
            "AdvancedNFT: Invalid function arguments"
        );

        for (uint256 i; i < from.length; i++) {
            _transfer(from[i], to[i], tokenId[i]);
        }
    }

    /**
     * @dev Withdraws contract balance to `_contributors`, splitting the payout
     * equally.
     */
    function withdrawToContributors() external {
        uint256 payout = address(this).balance / _contributors.length;

        for (uint256 i; i < _contributors.length; i++) {
            payable(_contributors[i]).send(payout);
        }
    }

    /**
     * @dev Advances contract state to the next stage.
     */
    function _nextStage() internal {
        stage = Stages(uint256(stage) + 1);
    }

    /**
     * @dev Uses the provided `merkleProof` to verify the proposed `merkleLeaf`
     * is in the set.
     */
    function _merkleProofVerify(
        bytes32[] memory merkleProof,
        bytes32 merkleLeaf
    ) internal view returns (bool) {
        return MerkleProof.verify(merkleProof, merkleRoot, merkleLeaf);
    }

    /**
     * @dev Returns the hashed data of the merkle leaf.
     *
     * The merkle leaf is a keccak256 hash of the address and its index in the
     * bitmap.
     */
    function _merkleLeaf(address account, uint256 ticketNumber)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(account, ticketNumber));
    }
}
