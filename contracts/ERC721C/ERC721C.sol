// SPDX-License-Identifier: MIT
// ERC721C Contracts v0.1.0
// Creator: creco.xyz

pragma solidity ^0.8.17;

import "../core/TokenList.sol";

contract ERC721C is TokenList {

  struct Account {
    uint16  balance;
    uint16  first; // first token ID owned
    uint16  last;  // last  token ID owned
  }

  function getPointer(address addr) internal pure returns(bytes32) {
    // return keccak256(abi.encode("creco::", addr));
    return bytes32(abi.encode(addr));
  }

  function getAccount(bytes32 ptr) internal pure returns(Account storage acc) {
    assembly { acc.slot := ptr }
  }

  function getAccount(address addr) internal pure returns(Account storage acc) {
    bytes32 ptr = getPointer(addr);
    return getAccount(ptr);
  }

  function supply() public view returns(uint16){
    return length;
  }

  function balanceOf(address owner) public view virtual returns (uint256) {
    return getAccount(owner).balance;
  }

  function getFirstOwned(address owner) public view returns (uint tokenId) {
    return getAccount(owner).first;
  }

  function getOwnedTokens(address owner) public view returns (uint16[] memory tokens) {
    Account storage acc = getAccount(owner);
    // owner, start, until (full length), max
    return _getOwnedTokens(owner, acc.first, length, acc.balance);
  }

  function _transfer(
    address from,
    address to,
    uint16 tokenId
  ) internal virtual {
    require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
    require(to != address(0), "ERC721: transfer to the zero address");

    // _beforeTokenTransfer(from, to, tokenId);

    // Clear approvals from the previous owner
    // _approve(address(0), tokenId);

    // ##### UPDATE BALANCES ####

    Account storage fromAcc = getAccount(from);
    Account storage toAcc = getAccount(to);
    fromAcc.balance -= 1;
    toAcc.balance += 1;

    // TODO move to TokenList
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
    if (toAcc.first > tokenId) {
      // => tokenId becomes new first
      _owners[tokenId].next = toAcc.first;
      toAcc.first = tokenId;
    } 
    else {
      //new id is in between first and last

      // ##### UPDATE POINTERS FOR NEW OWNER (to) ####
      // optimization: if account owns ID higher than tokenId
      // we need to check that the pointer order stays maintained
      // and the new token is not skipped

      // toAcc.first < tokenId &&
      if (toAcc.last > tokenId) {
        // we need to check if `to` has a node with .next pointer higher 
        // than tokenId and update pointers for the nodes
        uint16 current = toAcc.first;
        while(current < supply()) {
          // we found the end of one batch
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
      // toAcc.first < tokenId &&
      // toAcc.last < tokenId
      // => tokenId becomes new last
      else {
        // set pointer to new last
        _owners[toAcc.last].next = tokenId;
        toAcc.last = tokenId;
      }
    }

    // emit Transfer(from, to, tokenId);

    // _afterTokenTransfer(from, to, tokenId);
  }

  function transfer(
    address from,
    address to,
    uint16 tokenId
  ) public {
    _transfer(from, to, tokenId);
  }

  function mint(address to) public {
    mintBatch(to, 1);
  }

  function mintBatch(address to, uint16 amount) public {
    Account storage acc = getAccount(to);
    uint16 startIndex = supply() + 1;
    uint16 offset = amount;
    uint16 pos = startIndex + offset - 1;
    _owners[pos].owner = to;
    acc.balance += amount;
    // if this is the minter's first mint we set the start index pointer
    if (acc.first == 0) {
      acc.first = startIndex;
    } else {
      // if the owner minted previously, set a pointer to this batch
      // on last element of last batch
      // this will allow forward iteration: when end of batch is reached jump to next
      _owners[acc.last].next = startIndex;
    }
    // set last pointer to highest position
    acc.last = pos;
    length += amount;
  }

}