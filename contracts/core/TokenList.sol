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
  uint16 internal _length = 0;

  constructor() {
    // TODO for testing only
    _owners[0].owner = address(0xdEad000000000000000000000000000000000000);
  }

  // implemented by derived
  function getFirstOwned(address owner) virtual internal view returns(uint16);
  function getLastOwned(address owner) virtual internal view returns(uint16);

  function _append(address to, uint16 quantity) internal {

    // if the owner minted previously, set a pointer
    // on last element of last batch to first on new batch
    // this will allow forward iteration: when end of batch is reached jump to next
    if(getFirstOwned(to) < _length) {
      _owners[getLastOwned(to)].next = _length + 1;
    }

    _length += quantity;

    // terminate sublist with owner info
    _owners[_length].owner = to;

  }

  // find owner of token ID in: O(max(balance))
  // this can be optimized further by inserting partition node which just include owner and next: tokenId +1 
  // in the middle of a large batch
  function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
    require(tokenId > 0 && tokenId <= _length, "Invalid Token ID");
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

  function _transferOwnership(address from, address to, uint16 tokenId) internal {
    // ##### UPDATE OWNERSHIP AND POINTERS FOR PREVIOUS OWNER (from) ####
    if (tokenId == 1) {
      // we set the new owner and are done
      _owners[tokenId].owner = to;
    } 
    // in the following block tokenId - 1 is safe
    else {
      // if owner is empty the token ID lies within a batch mint
      if (_owners[tokenId].owner == address(0)) {
        // we need to introduce a new termination node one node before tokenId
        // from = previous owner. no don't need to sequentially search for it (checked with ownerOf)
        // terminate the batch before new owner to avoid that 
        // they become owner of ALL tokens in batch
        _owners[tokenId - 1].owner = from;
        // no need to check bounds: if node is empty there is at least a termination node
        // create "bridge" over inserted token to skip it
        _owners[tokenId - 1].next  = tokenId + 1;
      }
      // slot where we write is not empty: single mint or batch termination node
      else {
        // we are about to overwite a termination node.
        // move the temrination node one place forward
        if (_owners[tokenId - 1].owner == address(0)) {
          // copy node to new spot
          _owners[tokenId - 1].owner = _owners[tokenId].owner;
          _owners[tokenId - 1].next  = _owners[tokenId].next;
        }
      }
      // now set the new owner
      _owners[tokenId].owner = to;
    }

    // ##### UPDATE FIRST and LAST values on accounts ####
    if (getFirstOwned(to) > tokenId) {
      // => tokenId becomes new first
      _owners[tokenId].next = getFirstOwned(to);
      // toAcc.first = tokenId;
      return;
    } 

    if (getLastOwned(to) < tokenId) {
      // => tokenId becomes new last
      _owners[getLastOwned(to)].next = tokenId;
      return;
    } 

    // ==> new id is in between first and last:
    // toAcc.first < tokenId && toAcc.last > tokenId

    // ##### UPDATE POINTERS FOR NEW OWNER (to) ####
    // if account owns ID higher than tokenId
    // we need to check that the pointer order stays maintained
    // and the new token is not skipped in list

    // we need to check if `to` has a node with .next pointer higher 
    // than tokenId and update pointers for the nodes
    uint16 current = getFirstOwned(to);
    while(current < _length) {
      // we found the end of one batch
      // note: the list is sparse: next pointers might not be set
      // for all nodes within a batch
      if (_owners[current].owner == to) {
        // if there is a pointer continue at pos
        if (_owners[current].next != 0) {

          if (_owners[current].next > tokenId) {
            // we found a next-pointer larger than tokenId
            // to avoid the new node being skipped we update both pointers
            _owners[tokenId].next = _owners[current].next;
            _owners[current].next = tokenId;
            break; // done
          }

          current = _owners[current].next;
          continue;
        }
        // else done
      } else {
        current++;
      }
    }
  }

}