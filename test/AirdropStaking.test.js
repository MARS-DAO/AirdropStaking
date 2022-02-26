const { expectRevert, time,BN,ether} = require('@openzeppelin/test-helpers');
const { ethers, network } = require('hardhat');
const AirdropStaking = artifacts.require('AirdropStaking');
const MarsDAOStakingNFT= artifacts.require('MarsDAOStakingNFT');
const MockERC20 = artifacts.require('MockERC20');


contract('AirdropStaking', ([alice, bob, carol, scot,developer]) => {


    before(async () => {
        this.mars = await MockERC20.new('Mars', 'Mars', web3.utils.toWei("15000000", "ether"), { from: alice });
        this.marsDAOStakingNFT = await MarsDAOStakingNFT.new( { from: alice });
        this.airdropStaking = await AirdropStaking.new(this.marsDAOStakingNFT.address,this.mars.address,0, { from: alice });
        await this.mars.transfer(bob,web3.utils.toWei("1000000", "ether"),{ from: alice });
        await this.mars.transfer(carol,web3.utils.toWei("1000000", "ether"),{ from: alice });
        await this.mars.transfer(scot,web3.utils.toWei("1000000", "ether"),{ from: alice }); 
        await this.mars.approve(this.airdropStaking.address, web3.utils.toWei("1000000", "ether"), { from: bob });
        await this.mars.approve(this.airdropStaking.address, web3.utils.toWei("1000000", "ether"), { from: carol });
        await this.mars.approve(this.airdropStaking.address, web3.utils.toWei("1000000", "ether"), { from: scot });
        for(var i=1;i<12;i++){
            await this.marsDAOStakingNFT.airDrop([bob,carol,scot],i,1,{ from: alice });
        }
        this.marsVaultAddress=await this.airdropStaking.rewardsVault();
        await this.mars.transfer(this.marsVaultAddress,web3.utils.toWei("7200000", "ether"),{ from: alice });

    });

    it('deposit', async () => {
        var amounts=["0","500","1000","2000","4000","10000","12500","15000","20000","25000","50000","75000"];
        for(var i=1;i<12;i++){
            await this.airdropStaking.deposit(i,web3.utils.toWei(amounts[i], "ether"),{ from: bob });
            await this.airdropStaking.deposit(i,web3.utils.toWei(amounts[i], "ether"),{ from: carol });
            await this.airdropStaking.deposit(i,web3.utils.toWei(amounts[i], "ether"),{ from: scot });
        }
        expect(web3.utils.fromWei(await this.mars.balanceOf(bob))).to.eq('785000');
        expect(web3.utils.fromWei(await this.mars.balanceOf(carol))).to.eq('785000');
        expect(web3.utils.fromWei(await this.mars.balanceOf(scot))).to.eq('785000');
        expect(web3.utils.fromWei(await this.mars.balanceOf(this.airdropStaking.address))).to.eq('645000');
    });   

    it('harvest', async () => {
        
        var marsVaultBalance=await this.mars.balanceOf(this.marsVaultAddress);
        for (let i = 0; i < 28800; ++i) {
            await time.advanceBlock();
        }
        for(var i=1;i<12;i++){
            await this.airdropStaking.deposit(i,0,{ from: bob });
            await this.airdropStaking.deposit(i,0,{ from: carol });
            await this.airdropStaking.deposit(i,0,{ from: scot });
        }
        //8000 per day for all pools
        expect(Math.round((marsVaultBalance-(await this.mars.balanceOf(this.marsVaultAddress)))/1e18)).to.eq(8010);
    });

    it('withdraw', async () => {
        await time.increase(time.duration.years(1));

        var amounts=["0","500","1000","2000","4000","10000","12500","15000","20000","25000","50000","75000"];
        for(var i=1;i<12;i++){
            await this.airdropStaking.withdraw(i,web3.utils.toWei(amounts[i], "ether"),{ from: bob });
            await this.airdropStaking.withdraw(i,web3.utils.toWei(amounts[i], "ether"),{ from: carol });
            await this.airdropStaking.withdraw(i,web3.utils.toWei(amounts[i], "ether"),{ from: scot });
        }
        
    });

});