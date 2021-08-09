const { assert } = require('console');
//const { artifacts } = require('hardhat');
const {
    advanceBlock,
    advanceToBlock,
    increaseTime,
    increaseTimeTo,
    duration,
    revert,
    latestTime
  } = require('truffle-test-helpers');

const Cash = artifacts.require('Cash');
const Share = artifacts.require('Share');
const Board = artifacts.require('Boardroom');
const MockTreasury = artifacts.require('MockTreasury');

function toBN(x) {
    return '0x' + (Math.floor(x * (10 ** 18))).toString(16);
}

function toBN2(x) {
    return Math.floor(x * (10 ** 18));
}


contract('Update', ([alice, bob, carol, duck]) => {
    beforeEach(async () => {
        
        this.cash = await Cash.new("CASH", {from: alice});
        this.share = await Share.new("Share", {from: alice});
        this.board = await Board.new(this.cash.address, this.share.address, {from: alice});
        this.mockTreasury = await MockTreasury.new(this.cash.address, alice, this.board.address, {from: alice});
    });


    
    /*it("test", async () => {
        
        console.log(await this.cash.name());
        await this.cash.setMinter(alice, toBN(100000));
        await this.cash.setScaleOperator(alice);

        await this.cash.mint(bob, toBN(1000));
        await this.cash.mint(carol, toBN(100));

        console.log(await this.cash.balanceOf(bob));
        console.log(await this.cash.totalSupply());
        await this.cash.setScale(2000000);
        console.log(await this.cash.balanceOf(bob));
        console.log(await this.cash.totalSupply());
        await this.cash.transfer(duck, toBN(50), {from: carol});
        console.log(await this.cash.balanceOf(duck));
        console.log(await this.cash.balanceOf(carol));


    });*/


    it("board", async () => {
        await this.cash.setMinter(alice, toBN(100000));
        await this.cash.mint(alice, toBN(10000));
        await this.cash.setMinter(this.mockTreasury.address, toBN(100000));

        await this.cash.approve(this.board.address, toBN(10000000));
        await this.share.setMinter(alice, toBN(100000));
        await this.share.mint(alice, toBN(10000));
        await this.share.approve(this.board.address, toBN(10000000));

        await this.board.stake(toBN(50));
        //await this.board.allocateSeigniorage(toBN(50), {from: alice});
        await this.board.transferOperator(this.mockTreasury.address);
        await this.mockTreasury.allocateSeigniorage(toBN(50));
    });

    
   

});
