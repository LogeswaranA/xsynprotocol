import { useState, useContext } from 'react';
import './Xsyn.css';
const { executeTransaction, EthereumContext, log, queryData, convertPriceToEth, queryEvents } = require('react-solidity-web3');

function Xsyn() {

  const [submitting, setSubmitting] = useState(false);
  const { provider, XsynProtocol } = useContext(EthereumContext);

  const addKeyAddress = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let _name = "XSynExchange";
    let _destination = "0x85053735d6E2E82BA3Ffd42fcF9BA9020d98Ea5C";
    let response1 = await executeTransaction(XsynProtocol, provider, 'updateKeyAddress', [_name, _destination], 0);
    log("addKeyAddress", "hash", response1.txHash);
    setSubmitting(false);
  }

  const stakeXDCMintXDUSD = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let _stakeValue = await convertPriceToEth("200", "XDC");
    console.log("stakevalue is", _stakeValue);
    let response1 = await executeTransaction(XsynProtocol, provider, 'mintxdUSDForXDC', [], _stakeValue);
    log("stakeXDCMintXDUSD", "hash", response1.txHash);
    setSubmitting(false);
  }

  const updateDebtPool = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let _totUsdSwapped = await convertPriceToEth("1", "XDC");
    let _totSynthsPurchased = await convertPriceToEth("1", "XDC");
    let addr = "0x4e1945cEc2539a9be460aB0aa7BdC1EADebde75e";
    let _symbolPurchased = "XDPAX";
    console.log("_totUsdSwapped is", _totUsdSwapped, _totSynthsPurchased);
    let response1 = await executeTransaction(XsynProtocol, provider, 'updateDebtPool', [addr, _totUsdSwapped, _totSynthsPurchased, _symbolPurchased], 0);
    log("updateDebtPool", "hash", response1.txHash);
    setSubmitting(false);
  }

  const showMyDeposits = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let addr = "0x4e1945cEc2539a9be460aB0aa7BdC1EADebde75e";
    console.log("addr is", addr);
    let response1 = await queryData(XsynProtocol, provider, 'deposits', [addr]);
    log("showMyDeposits", "hash", response1);
    setSubmitting(false);
  }

  const queryAddress = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let _name = "XDUSD";
    let response1 = await queryData(XsynProtocol, provider, 'keyaddress', [_name]);
    log("queryAddress", "hash", response1)
    setSubmitting(false);
  }

  const showPrices = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let _name = "XDC";
    let response1 = await queryData(XsynProtocol, provider, 'showPrice', [_name]);
    log("showPrices", "hash", response1)
    setSubmitting(false);
  }

  const getMyCollateralRatio = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let addr = "0x4e1945cEc2539a9be460aB0aa7BdC1EADebde75e";
    let response1 = await queryData(XsynProtocol, provider, 'getMyCollateralRatio', [addr]);
    log("getMyCollateralRatio", "hash", response1)
    setSubmitting(false);
  }

  const getMyEarnings = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let addr = "0x4e1945cEc2539a9be460aB0aa7BdC1EADebde75e";
    let response1 = await queryData(XsynProtocol, provider, 'GetEarnings', [addr]);
    log("getMyCollateralRatio", "hash", response1)
    setSubmitting(false);
  }

  const getEstimation = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let _totTokentoSend = await convertPriceToEth("200", "XDC");
    let _symbol = "XDC";
    let response1 = await queryData(XsynProtocol, provider, 'getEstimation', [_totTokentoSend, _symbol]);
    log("getMyCollateralRatio", "hash", response1)
    setSubmitting(false);
  }

  return <div className="Container">
    <div>
      <h1>getEstimation</h1><br></br>
      <form onSubmit={getEstimation}>
        <button type="submit" disabled={submitting}> {submitting ? 'Estimating..' : 'Get Estmation'}</button>
      </form>
    </div>
    <div></div>
    <div>
      <h1>AddKeyAddress</h1><br></br>
      <form onSubmit={addKeyAddress}>
        <button type="submit" disabled={submitting}> {submitting ? 'Adding..' : 'Add Key Address'}</button>
      </form>
    </div>
    <div>
      <h1>Query Address</h1><br></br>
      <form onSubmit={queryAddress}>
        <button type="submit" disabled={submitting}> {submitting ? 'Querying..' : 'Query Address'}</button>
      </form>
    </div>
    <div>
      <h1>stakeXDCMintXDUSD</h1><br></br>
      <form onSubmit={stakeXDCMintXDUSD}>
        <button type="submit" disabled={submitting}> {submitting ? 'Staking..' : 'Stake XDC'}</button>
      </form>
    </div>
    <div>
      <h1>showMyDeposits</h1><br></br>
      <form onSubmit={showMyDeposits}>
        <button type="submit" disabled={submitting}> {submitting ? 'Showing..' : 'Show Deposits '}</button>
      </form>
    </div>
    <div>
      <h1>getMyCollateralRatio</h1><br></br>
      <form onSubmit={getMyCollateralRatio}>
        <button type="submit" disabled={submitting}> {submitting ? 'Showing..' : 'Get My Collateral Ratio '}</button>
      </form>
    </div>
    <div>
      <h1>getMyEarnings</h1><br></br>
      <form onSubmit={getMyEarnings}>
        <button type="submit" disabled={submitting}> {submitting ? 'Earnings..' : 'Get My Earnings '}</button>
      </form>
    </div>
    <div>
      <h1>showPrices</h1><br></br>
      <form onSubmit={showPrices}>
        <button type="submit" disabled={submitting}> {submitting ? 'Show..' : 'Show Prices'}</button>
      </form>
    </div>
    <div>
      <h1>updateDebtPool</h1><br></br>
      <form onSubmit={updateDebtPool}>
        <button type="submit" disabled={submitting}> {submitting ? 'update..' : 'Update Debt'}</button>
      </form>
    </div>
  </div>
}



export default Xsyn;