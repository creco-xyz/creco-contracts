// SPDX-License-Identifier: MIT
// ERC721C Contracts v0.1.0
// Creator: creco.xyz

pragma solidity ^0.8.17;

abstract contract TokenList {

  struct OwnerNode {
    address owner; // 160 bits
    uint16  next;  // 128 bits
  }

  // tokenId => owner
  mapping (uint256 => OwnerNode) public _owners; // slot #0

  // MAX length / supply is capped at 2^16 = 65536
  uint16 public length = 0;

  constructor() {
    // TODO for testing only
    _owners[0].owner = address(0xdEad000000000000000000000000000000000000);
  }

  // find owner of token ID in: O(max(balance))
  // this can be optimized further by inserting partition node which just include owner and next: tokenId +1 
  // in the middle of a large batch
  function ownerOf(uint256 tokenId) public view virtual returns (address) {
    require(tokenId > 0 && tokenId <= length, "Invalid Token ID");
    while(
      // owner is stored at last pos of a batch
      // we need to iterate over all their tokens until we reach the last of batch
      _owners[tokenId].owner == address(0) 
    ) {
      tokenId++;
    }
    return _owners[tokenId].owner;
  }


  function _getOwnedTokens(address owner, uint16 start, uint16 end, uint16 max) public view returns (uint16[] memory tokens) {
    tokens = new uint16[](max);
    uint16 current = start;
    uint i = 0;
    // console.log("get owned tokens: %s", owner);
    while(i < max && current <= end) {
      // push token ID to owned
      tokens[i++] = current; 

      // we found the end of one batch
      if (_owners[current].owner == owner) {
        // if there is a pointer continue at pos
        if (_owners[current].next != 0) {
          current = _owners[current].next;
          continue;
        }
        // else: done
      } else {
        current++;
      }
    }
    return tokens;
  }

}