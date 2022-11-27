import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const deploy = async (name: string, ...args: any[]) => {
  const C = await ethers.getContractFactory(name);
  const contract = await C.deploy(...args);
  const res = await contract.deployed();
  const { deployTransaction } = res;
  const receipt = await deployTransaction.wait();
  // console.log(`${name} deployed to ${contract.address}`, formatGas(receipt.gasUsed));
  return contract;
};

describe.only("ERC721C", function () {

  let nft: Contract;
  let deployer: SignerWithAddress
  let user1: SignerWithAddress
  let user2: SignerWithAddress
  let user3: SignerWithAddress

  // ### HELPERS ####

  const getBalance = async (address: string) => {
    let _balance = await nft.balanceOf(address)
    return parseInt(_balance, 10)
  }


  const getOwned = async (address: string) => {
    const owned = await nft.getOwnedTokens(address)
    return owned.map((t: any) => parseInt(t.toString(), 10))
  }

  const removeItem = (arr: number[], item: number) => {
    return [...arr].filter(obj => obj !== item)
  }

  // ### DEPLOY ####

  const deployContracts = async (verbose = false) => {
    [deployer, user1, user2, user3] = await ethers.getSigners();
    nft = await deploy('ERC721C', "TestNFT", "TEST");
  }

  // also called for nested
  beforeEach(async () => {
    await deployContracts();
  });

  // ### TESTS ####

  it('can mint one', async () => {
    let tx
    let receipt

    const tokenId = '1'
    tx = await nft.mint(user1.address);
    receipt = await tx.wait()
    console.log('mint cost', receipt.gasUsed.toString())

    tx = await nft.mint(user2.address);
    receipt = await tx.wait()
    console.log('mint cost 2', receipt.gasUsed.toString())

    const owner = await nft.ownerOf(tokenId)
    expect(owner).to.equal(user1.address)

    const balance = await getBalance(user1.address)
    expect(balance).to.equal(1)
  })

  it('can batch mint', async () => {
    let tx
    let receipt

    const tokenId = '1'
    const amount = 5
    tx = await nft.mintBatch(user1.address, amount);
    receipt = await tx.wait()
    console.log('mint cost ', amount, receipt.gasUsed.toString())

    tx = await nft.mintBatch(user2.address, amount);
    let receipt2 = await tx.wait()
    console.log('mint cost 2', amount, receipt2.gasUsed.toString())

    const owner = await nft.ownerOf(amount-1)
    expect(owner).to.equal(user1.address)

    const balance = await getBalance(user1.address)
    expect(balance).to.equal(amount)

    let i = 0
    while (i++ < amount) {
      const owner = await nft.ownerOf(tokenId)
      expect(owner).to.equal(user1.address)
    }

  })


  describe("transfer()", () => {
    let balanceUser1Before: number
    let balanceUser2Before: number
    let ownedUser1Before: number[]
    let ownedUser2Before: number[]

    beforeEach(async () => {
      await deployContracts()
      // prepare storage layout
      /* this is the initial storage layout
      owner at 0  is 0xdead000000000000000000000000000000000000 <- reserved
      owner at 1  is 0x0000000000000000000000000000000000000000
      owner at 2  is 0x0000000000000000000000000000000000000000
      owner at 3  is 0x0000000000000000000000000000000000000000
      owner at 4  is 0x0000000000000000000000000000000000000000
      owner at 5  is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 <- user 1 next: -> 10
      owner at 6  is 0x0000000000000000000000000000000000000000
      owner at 7  is 0x0000000000000000000000000000000000000000
      owner at 8  is 0x0000000000000000000000000000000000000000
      owner at 9  is 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc <- user 2
      owner at 10 is 0x0000000000000000000000000000000000000000
      owner at 11 is 0x0000000000000000000000000000000000000000
      owner at 12 is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 <- user 1
      */
      let tx
      tx = await nft.mintBatch(user1.address, 5);
      await tx.wait()
      tx = await nft.mintBatch(user2.address, 4);
      await tx.wait()
      tx = await nft.mintBatch(user1.address, 3);
      await tx.wait()

      balanceUser1Before = await getBalance(user1.address)
      expect(balanceUser1Before).to.equal(5 + 3)

      balanceUser2Before = await getBalance(user2.address)
      expect(balanceUser2Before).to.equal(4)

      ownedUser1Before = await getOwned(user1.address)
      expect(ownedUser1Before).to.have.members([1, 2, 3, 4, 5, 10, 11, 12])

      ownedUser2Before = await getOwned(user2.address)
      expect(ownedUser2Before).to.have.members([6, 7, 8, 9])
    })

    it('A) can transfer tokens from middle of batch', async () => {
      let tx

      // 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc (user2) transfers #7 to 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 (user1)
      const tokenId = '7'
      const ownerBefore = await nft.ownerOf(tokenId)
      expect(ownerBefore).to.equal(user2.address)

      /*
      we set #7 to new owner. but this would also give them #6
      owner at 0  is 0xdead000000000000000000000000000000000000 <- reserved
      owner at 1  is 0x0000000000000000000000000000000000000000
      owner at 2  is 0x0000000000000000000000000000000000000000
      owner at 3  is 0x0000000000000000000000000000000000000000
      owner at 4  is 0x0000000000000000000000000000000000000000
      owner at 5  is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 <- user 1
      owner at 6  is 0x0000000000000000000000000000000000000000 <- PROBLEM
      owner at 7  is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 <- new owner user 1
      owner at 8  is 0x0000000000000000000000000000000000000000
      owner at 9  is 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc <- user 2
      owner at 10 is 0x0000000000000000000000000000000000000000
      owner at 11 is 0x0000000000000000000000000000000000000000
      owner at 12 is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 <- user 1

      so we have to update owner at #6
      owner at 0  is 0xdead000000000000000000000000000000000000 <- reserved
      owner at 1  is 0x0000000000000000000000000000000000000000
      owner at 2  is 0x0000000000000000000000000000000000000000
      owner at 3  is 0x0000000000000000000000000000000000000000
      owner at 4  is 0x0000000000000000000000000000000000000000
      owner at 5  is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 <- user 1
      owner at 6  is 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc <- FIXED
      owner at 7  is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 <- new owner user 1
      owner at 8  is 0x0000000000000000000000000000000000000000
      owner at 9  is 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc <- user 2
      owner at 10 is 0x0000000000000000000000000000000000000000
      owner at 11 is 0x0000000000000000000000000000000000000000
      owner at 12 is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 <- user 1

      we also need to update the linked list pointers for "from" (a)
      and "to" (b)
      owner at 3  is 0x0000000000000000000000000000000000000000
      owner at 4  is 0x0000000000000000000000000000000000000000
      owner at 5  is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 (b) next: 10 -> 7
      owner at 6  is 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc (a) next: -> 8
   -> owner at 7  is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 (b) next: -> 10
      owner at 8  is 0x0000000000000000000000000000000000000000
      owner at 9  is 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc 
      owner at 10 is 0x0000000000000000000000000000000000000000
      owner at 11 is 0x0000000000000000000000000000000000000000
      owner at 12 is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 
      */
      tx = await nft.connect(user2).transfer(user2.address, user1.address, tokenId)
      await tx.wait()

      const balanceUser1After = await getBalance(user1.address)
      expect(balanceUser1After).to.equal(balanceUser1Before + 1)

      const balanceUser2After = await getBalance(user2.address)
      expect(balanceUser2After).to.equal(balanceUser2Before - 1)

      const ownerAfter = await nft.ownerOf(tokenId)
      expect(ownerAfter).to.equal(user1.address)

      const owned1 = await getOwned(user1.address)
      expect(owned1).to.have.members([...ownedUser1Before, 7])

      const owned2 = await getOwned(user2.address)
      expect(owned2).to.have.members(removeItem(ownedUser2Before, 7))
    })

    it('B) handles transfer of tokenId that is before / smaller than the start index of the new owners current account', async () => {
      let tx

      // 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 (user1) transfers #3 to 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc (user2)
      const tokenId = '3'
      const ownerBefore = await nft.ownerOf(tokenId)
      expect(ownerBefore).to.equal(user1.address)

      /*
      owner at 0  is 0xdead000000000000000000000000000000000000 <- reserved
      owner at 1  is 0x0000000000000000000000000000000000000000 [u1: first]
      owner at 2  is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 next: -> 4
  ->  owner at 3  is 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc next: -> 6 (token Id < first: set pointer to first)
      owner at 4  is 0x0000000000000000000000000000000000000000
      owner at 5  is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 <- user 1 next: -> 10
      owner at 6  is 0x0000000000000000000000000000000000000000 [u2: first]
      owner at 7  is 0x0000000000000000000000000000000000000000
      owner at 8  is 0x0000000000000000000000000000000000000000
      owner at 9  is 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc <- user 2 [u2: last]
      owner at 10 is 0x0000000000000000000000000000000000000000
      owner at 11 is 0x0000000000000000000000000000000000000000
      owner at 12 is 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 <- user 1 [u1: last]
      */

      tx = await nft.connect(user1).transfer(user1.address, user2.address, tokenId)
      await tx.wait()

      const owned1 = await getOwned(user1.address)
      expect(owned1).to.have.members(removeItem(ownedUser1Before, 3))

      const owned2 = await getOwned(user2.address)
      expect(owned2).to.have.members([...ownedUser2Before, 3])

    })

  })

})