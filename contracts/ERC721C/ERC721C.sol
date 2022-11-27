// SPDX-License-Identifier: MIT
// ERC721C Contracts v0.1.0
// Creator: creco.xyz

pragma solidity ^0.8.17;

import "../core/TokenList.sol";
import "./IERC721Basic.sol"; // no approvals
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract AccountStorage {
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
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract ERC721C is TokenList, AccountStorage, IERC721Basic, ERC165 {

  // Token name
  string public name;

  // Token symbol
  string public symbol;

  /*//////////////////////////////////////////////////////////////
                          TokenList LOGIC
  //////////////////////////////////////////////////////////////*/

  function getFirstOwned(address owner) internal view override returns (uint16 tokenId) {
    return getAccount(owner).first;
  }

  function getLastOwned(address owner) internal view override returns(uint16) {
    return getAccount(owner).last;
  }

  function getOwnedTokens(address owner) public view returns (uint16[] memory tokens) {
    Account storage acc = getAccount(owner);
    // owner, start, until (full length), max
    return _getOwnedTokens(owner, acc.first, _length, acc.balance);
  }

  /*//////////////////////////////////////////////////////////////
                          ERC721 LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
  * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
  */
  constructor(string memory name_, string memory symbol_) {
      name = name_;
      symbol = symbol_;
  }

  function supply() public view returns(uint16){
    // supply is length of TokenList
    return _length;
  }

  function balanceOf(address owner) public view virtual returns (uint16) {
    return getAccount(owner).balance;
  }

  function ownerOf(uint16 tokenId) external view returns (address owner) {
    return _ownerOf(tokenId);
  }

  function _transfer(
    address from,
    address to,
    uint16 tokenId
  ) internal virtual {
    require(_ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
    require(to != address(0), "ERC721: transfer to the zero address");

    // _beforeTokenTransfer(from, to, tokenId);

    // Clear approvals from the previous owner
    // _approve(address(0), tokenId);

    // ##### UPDATE BALANCES ####
    Account storage fromAcc = getAccount(from);
    Account storage toAcc = getAccount(to);
    unchecked {
      fromAcc.balance -= 1;
      toAcc.balance += 1;
    }

    _transferOwnership(from, to, tokenId);

    if(tokenId > toAcc.last) {
      toAcc.last = tokenId;
    }
    if(tokenId < toAcc.first) {
      toAcc.first = tokenId;
    }

    emit Transfer(from, to, tokenId);

    // _afterTokenTransfer(from, to, tokenId);
  }

  function transfer(
    address from,
    address to,
    uint16 tokenId
  ) public {
    _transfer(from, to, tokenId);
  }

  function transferFrom(
      address from,
      address to,
      uint16 tokenId
  ) public {
    // TODO implement approvals
    _transfer(from, to, tokenId);
  }

  function safeTransferFrom(
      address from,
      address to,
      uint16 tokenId,
      bytes calldata data
  ) public {
    transferFrom(from, to, tokenId);
    if (to.code.length != 0) {
      require(
        ERC721TokenReceiver(to).onERC721Received(msg.sender, from, tokenId, data) == ERC721TokenReceiver.onERC721Received.selector,
        "UNSAFE_RECIPIENT"
      );
    }
  }

  function safeTransferFrom(
      address from,
      address to,
      uint16 tokenId
  ) external {
    transferFrom(from, to, tokenId);
    if (to.code.length != 0) {
      require(
        ERC721TokenReceiver(to).onERC721Received(msg.sender, from, tokenId, "") == ERC721TokenReceiver.onERC721Received.selector,
        "UNSAFE_RECIPIENT"
      );
    }
  }


  /**
  * @dev See {IERC165-supportsInterface}.
  */
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
    return
        //interfaceId == type(IERC721).interfaceId ||
        //interfaceId == type(IERC721Metadata).interfaceId ||
        super.supportsInterface(interfaceId);
  }

  /*//////////////////////////////////////////////////////////////
                      INTERNAL MINT LOGIC
  //////////////////////////////////////////////////////////////*/

  function mint(address to) public {
    mintBatch(to, 1);
  }

  function mintBatch(address to, uint16 quantity) public {
    Account storage acc = getAccount(to);
    // e.g. supply = 0, first tokenId is 1
    uint16 l = supply();
    uint16 startIndex = l + 1; 
    uint16 end = l + quantity;

    acc.balance += quantity;

    // if this is the minter's first mint we set the start index pointer
    if (acc.first == 0) {
      acc.first = startIndex;
    }

    // this will update supply
    _append(to, quantity);
    
    // set last pointer to highest position
    acc.last = end;

    while(startIndex < end) {
      emit Transfer(address(0), to, startIndex++);
    }

  }

}