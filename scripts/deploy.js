const { ethers } = require('hardhat');
const { writeFileSync } = require('fs');

async function deploy(name, ...params) {
  const Contract = await ethers.getContractFactory(name);
  return await Contract.deploy(...params).then(f => f.deployed());
}

async function main() {
  const safeDecMath = await deploy('SafeDecimalMath');
  console.log("SafeDecimalMath deployed", safeDecMath.address)
  const addr = await deploy('AddressResolver');
  console.log("AddressResolver deployed", addr.address)
  const exchange = await deploy('ExchangeRate', "0x33f4212b027e22af7e6ba21fc572843c0d701cd1", "0x97A6d407f4CD30936679d0a28A3bc2A7F13a2185", "839e3a5a88eb4c59aafb1fcedcdc0dd7");
  console.log("ExchangeRate deployed", exchange.address);

  const xSynContract = await ethers.getContractFactory("XSynProtocol", {
    libraries: {
      SafeDecimalMath: safeDecMath.address,
    },
  });
  const xSyn = await xSynContract.deploy(200).then(f => f.deployed());;
  console.log("XSyn Protocol deployed", xSyn.address);

  const xdusd = await deploy('XDUSDCore', "XDUSD Contract", "XDUSD", xSyn.address);
  console.log("XDUSDCore deployed", xdusd.address)


  const XSynExchange = await ethers.getContractFactory("XSynExchange", {
    libraries: {
      SafeDecimalMath: safeDecMath.address,
    },
  });
  const xsynexchange = await XSynExchange.deploy().then(f => f.deployed());;
  console.log("XSynExchange deployed", xsynexchange.address);

  const xdbtc = await deploy('XDBTC', "XDBTC Contract", "XDBTC", xsynexchange.address);
  console.log("XDBTC deployed", xdbtc.address)

  const xdeth = await deploy('XDETH', "XDETH Contract", "XDETH", xsynexchange.address);
  console.log("XDETH deployed", xdeth.address)

  const xdpax = await deploy('XDPAX', "XDPAX Contract", "XDPAX", xsynexchange.address);
  console.log("XDPAX deployed", xdpax.address)
  

  writeFileSync('output.json', JSON.stringify({
    XSYNPROTOCOL: xSyn.address,
    ADDRESSRESOLVER: addr.address,
    EXCHANGE: exchange.address,
    XDUSDCORE: xdusd.address,
    XSynExchange: xsynexchange.address,
    XDBTC: xdbtc.address,
    XDETH: xdeth.address,
    XDPAX: xdpax.address,
    SafeDecimalMath:safeDecMath.address
  }, null, 2));
}
if (require.main === module) {
  main().then(() => process.exit(0))
    .catch(error => { console.error(error); process.exit(1); });
}