# Week 9: Miscellaneous Advanced Topics

## AddressHacks.sol

A simple set of smart contracts that shows how extcodesize can be bypassed in the constructor.

## truster-exploit.js

Damn Vulnerable DeFi challenge #3.

## AdvancedNFT.sol

An NFT with merkle tree airdrop, random allocation via commit reveal, multicall transfers, a state machine pattern, and withdrawal to designated addresses via pull pattern.

## Questions

### Should you be using pausable or nonReentrant in your NFT? Why or why not?

Pausable - maybe. It's a judgement call in which decentralization is sacrified for some added control and security.

nonReentrant - no. The withdrawToContributors function is the only function that could conceivably contain a re-entrancy vulnerability and it doesn't.

### What trick does OpenZeppelin use to save gas on the nonReentrant modifier?

The modifier uses two uint256 global state variables instead of a simple boolean to track whether the function has already been entered. Booleans are more expensive than uint256 or any type that takes up a full word.
