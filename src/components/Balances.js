import React, { Component } from 'react'
import { Button, Label, Input } from 'reactstrap'
import { KOVAN_NETWORK_ID, ETCLocking, ETCToken, ETC_LOCKING_ADDRESS, ETC_TOKEN_ADDRESS } from './Constants.js';

export default class Balances extends Component {
	constructor(props) {
		super(props);
		this.state = {
			kovanBalance: 0,
			ropstenBalance: 0,
			kovanAddress: "",
			ropstenAddress: ""
		}
		
		this.queryBalance = this.queryBalance.bind(this);
		this.handleChange = this.handleChange.bind(this);
	}

	queryBalance(queryNetwork) {
		console.log(queryNetwork)
		if (!this.props.web3) {
			return;
		}

		if (queryNetwork == 'kovan') {
			//ETCLocking has no method balanceOf. Consider storing balances to see how much ETH each person has locked up
			/*
			let data = ETCLocking.balanceOf.getData(this.state.kovanAddress);
			var balanceResult = InfuraKovan.eth.call({
				data: data,
				to: ETC_LOCKING_ADDRESS
			});
			this.setState({kovanBalance: InfuraKovan.fromWei(balanceResult, 'ether')});
			*/
		} else {
			let balance = ETCToken.balanceOf(this.state.ropstenAddress)
			balance = this.props.web3.fromWei(balance, 'ether').toNumber()
			console.log(balance)
			if (balance != this.state.ropstenBalance) {
				this.setState({ropstenBalance: balance})
			}
		}
	}

	handleChange(event) {
		this.setState({[event.target.name]: event.target.value});
	}

	render() {
		return (
			<div className="tokenBalance">
				<h4 className="tokenBalanceTitle">Locked ETH in Kovan</h4>
				<hr className="divider"/>
				<p>{this.state.kovanBalance} ETH</p>
	            <Input type='text' name="kovanAddress" placeholder="Wallet Address" value={this.state.kovanAddress} onChange={this.handleChange}/>
	          	<Button color="info" onClick={() => this.queryBalance('kovan')} block>Query</Button>
				<br />
				<h4 className="tokenBalanceTitle">ETC Tokens in Ropsten</h4>
				<hr className="divider"/>
				<p>{this.state.ropstenBalance} ETC</p>
	            <Input type='text' name="ropstenAddress" placeholder="Wallet Address" value={this.state.ropstenAddress} onChange={this.handleChange}/>
	          	<Button color="info" onClick={() => this.queryBalance('ropsten')} block>Query</Button>
			</div>
		);
	}
}