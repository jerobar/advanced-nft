// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// import "@openzeppelin/contracts/utils/Multicall.sol";

// TODO:
// - Use OZ bitmap to handle presale purchases
// - TransferMultiple functionality

contract AdvancedNFT is ERC721 {
    using BitMaps for BitMaps.BitMap;

    bytes32 public immutable merkleRoot;

    mapping(address => bool) private _contributors;

    uint256 public revealBlockNumber;
    uint256 public metadataRandomSeed;

    BitMaps.BitMap private _presaleAllocations;
    uint256 public PRICE = 0.05 ether;
    uint256 public immutable MAX_SUPPLY_CAP = 10000;
    // measure gas vs. bitmap (hardhat? REPORT_GAS=true npx hardhat test)
    // mapping(address => uint256) public balances;

    enum Stages {
        PresaleMinting, // commit/reveal stage?
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
        require(
            msg.value == PRICE,
            "AdvancedNFT: Insufficient transaction value"
        );
        _;
    }

    modifier isNotContract() {
        require(
            msg.sender == tx.origin,
            "AdvancedNFT: Feature is limited to EOAs only"
        );
        _;
    }

    modifier msgSenderIsContributor() {
        require(
            _contributors[msg.sender],
            "AdvancedNFT: Feature is limited to contributors only"
        );
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        bytes32 root
    ) ERC721(name, symbol) {
        merkleRoot = root;
        _contributors[msg.sender] = true;
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
     * - At or beyond reveal block number
     * - `metadataRandomSeed` not yet set
     */
    function reveal() external atStage(Stages.PresaleMinting) {
        require(
            block.number > revealBlockNumber - 1,
            "AdvancedNFT: Cannot reveal yet"
        );
        require(metadataRandomSeed == 0, "AdvancedNFT: Already revealed");

        metadataRandomSeed = blockHash(revealBlockNumber);
    }

    /**
     * @dev Returns the URI of `tokenId` which is "randomized" by being offset
     * within the list of token id's as a function of `metadataRandomSeed`.
     *
     * Requirements:
     *
     * - `tokenId` has been minted
     */
    function tokenURI(uint256 tokenId) external returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();

        // Offset `metadataId` as a function of the `metadataRandomSeed`
        uint256 metadataId = (tokenId + metadataRandomSeed) % MAX_SUPPLY_CAP;

        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, metadataId.toString()))
                : "";
    }

    function mint() external msgValueEqualsPRICE {
        // Just calculate the offset by totalSupply() here to get this assignment done...
    }

    /**
     * @dev
     *
     * Requirements:
     *
     * - At stage `Presale`
     * - `msg.sender` is not contract
     * - `msg.value` == `PRICE`
     * - Caller provided valid `merkleProof`
     * - `tokenId` not already minted
     */
    function presale(uint256 tokenId, bytes32[] calldata merkleProof)
        external
        atStage(Stages.Presale)
        isNotContract
        msgValueEqualsPRICE
    {
        require(
            _merkleProofVerify(merkleProof, _merkleLeaf(msg.sender, tokenId)), // tokenId == ticketNumber ?
            "AdvancedNFT: Invalid merkle proof"
        );
        require(
            get(_presaleAllocations, tokenId),
            "AdvancedNFT: Token already minted"
        );

        // Mark this `tokenId` as minted
        set(_presaleAllocations, tokenId);

        // Are we always minting `totalSupply()` below regardless?

        // Is the tokenId is the index in the bitmap?

        _mint(msg.sender, tokenId);
    }

    // args: tokenId?
    function publicSale()
        external
        atStage(Stages.PublicSale)
        isNotContract
        msgValueEqualsPRICE
    {
        // _mint(msg.sender, tokenId);
    }

    function transferMultiple() external {
        // Add multicall to the NFT so people can transfer several NFTs in one transaction (make sure people can’t abuse minting!)
    }

    /**
     * @dev Adds `contributor` to `_contributors`.
     *
     * Requirements:
     *
     * - - `msg.sender` is a contributor
     */
    function addContributor(address contributor)
        external
        msgSenderIsContributor
    {
        _contributors[contributor] = true;
    }

    /**
     * @dev Withdraws contract balance to `contributors`, splitting the payout
     * equally.
     *
     * Requirements:
     *
     * - `msg.sender` is a contributor
     *
     * Note: Vulnerability here in that one malicious contributor can withdraw
     * all funds to their own wallet.
     */
    function withdrawToContributors(address[] calldata contributors)
        external
        msgSenderIsContributor
    {
        uint256 payout = address(this).balance / contributors.length;

        for (uint256 i; i < contributors.length; i++) {
            require(
                _contributors[contributors[i]],
                "AdvancedNFT: Can only withdraw to contributors"
            );

            _withdrawToContributor(payable(contributors[i]), payout);
        }
    }

    /**
     * @dev Withdraws `amount` payout to `contributor` address.
     */
    function _withdrawToContributor(address payable contributor, uint256 amount)
        internal
    {
        payable(contributor).send(amount);
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
    function _merkleLeaf(address account, uint256 tokenId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(account, tokenId));
    }
}
