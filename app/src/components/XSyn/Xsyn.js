import { useState, useContext } from 'react';
import './Xsyn.css';
const { executeTransaction, EthereumContext, log, queryData ,convertPriceToEth} = require('react-solidity-web3');

function Xsyn() {
  const [submitting, setSubmitting] = useState(false);
  const { provider, XsynProtocol } = useContext(EthereumContext);

  const addKeyAddress = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let _name =  "XSynExchange";
    let _destination = "0xC851bDE4a6c285e629762066eE349C0833684712";
    let response1 = await executeTransaction(XsynProtocol, provider, 'updateKeyAddress',[_name,_destination] , 0);
    log("addKeyAddress", "hash", response1.txHash);
    setSubmitting(false);
  }

  const stakeXDCMintXDUSD = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let _stakeValue = await convertPriceToEth("1000","XDC");
    console.log("stakevalue is",_stakeValue);
    let response1 = await executeTransaction(XsynProtocol, provider, 'mintxdUSDForXDC',[] , _stakeValue);
    log("stakeXDCMintXDUSD", "hash", response1.txHash);
    setSubmitting(false);
  }

  const queryAddress = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    let _name =  "XSynExchange";
    let response1 = await queryData(XsynProtocol, provider, 'keyaddress', [_name]);
    log("queryAddress", "hash", response1)
    setSubmitting(false);
  }

  return <div className="Container">
    <div>
      <h1>stakeXDCMintXDUSD</h1><br></br>
      <form onSubmit={stakeXDCMintXDUSD}>
        <button type="submit" disabled={submitting}> {submitting ? 'Staking..' : 'Stake XDC'}</button>
      </form>
    </div>
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
    {/* <div>
      <h1>Fetch</h1><br></br>
      <form onSubmit={fetchFlight}>
        <button type="submit" disabled={submitting}>{submitting ? 'Fetching..' : 'Fetch Flights '}</button>
      </form>
    </div> */}
  </div>
}



export default Xsyn;