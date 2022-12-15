// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IExchangeRate.sol";
import "./interfaces/IXDUSDCore.sol";
import "./AddressResolver.sol";
import "./utils/Constants.sol";
import "./utils/SafeDecimalMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract XSynProtocol is Constants, AddressResolver {
    using SafeMath for uint256;
    using SafeDecimalMath for uint256;

    string public constant CONTRACTNAME = "XSynProtocol";
    string internal constant CONTRACT_XDUSDCORE = "XDUSD";
    string internal constant CONTRACT_EXCHANGERATE = "EXCHANGERATE";
    string internal constant CONTRACT_XSYNEXCHANGE = "XSynExchange";

    uint256 public minCRatio;

    // mapping(address => uint256) public mintr;
    address public contractOwner;

    uint256 public minimumXDCDepositAmount = 10000 * SafeDecimalMath.unit();
    uint256 public minimumPLIDepositAmount = 20000 * SafeDecimalMath.unit();

    /* Stores deposits from users. */
    struct DepositEntry {
        // The user that made the deposit
        address payable user;
        // The amount (in xdc / pli) that they deposited
        uint256 xdcDeposit;
        uint256 pliDeposit;
        uint256 xdUsdminted;
        // type of (coin/token) that they deposited
        TokenType tok;
    }

    mapping(address => uint256) public totalXDUSDMinted;
    mapping(address => uint256) public totalXDUSDSwapped;

    //DebtPool will track the swaps and the trading
    struct DebtPool {
        address payable user;
        string xSynSymbol;
        uint256 synthValue;
        bool loanSettled;
    }

    mapping(address => DepositEntry) public deposits;
    mapping(address => mapping(string => DebtPool)) public debtTotalPool;

    constructor(uint256 cratio) {
        contractOwner = msg.sender;
        minCRatio = cratio;
    }

    /**
     * @notice Fallback function
     */
    receive() external payable {}

    function setMinDepositForXDC(uint256 _minDeposit) external onlyAuthorized {
        minimumXDCDepositAmount = _minDeposit;
        emit MinimumDepositAmountUpdated(minimumXDCDepositAmount);
    }

    function setMinDepositForPLI(uint256 _minDeposit) external onlyAuthorized {
        minimumPLIDepositAmount = _minDeposit;
        emit MinimumDepositAmountUpdated(minimumPLIDepositAmount);
    }

    function _onlyAuthorized() internal view {
        require(
            msg.sender == contractOwner,
            "Only XSynProtocol can perform this operation"
        );
    }

    modifier onlyAuthorized() {
        _onlyAuthorized();
        _;
    }

    function _onlyExchanger() internal view {
        require(
            msg.sender == XsynExchanger(),
            "Only XsynExchange can perform this operation"
        );
    }

    modifier onlyExchanger() {
        _onlyExchanger();
        _;
    }

    /**
     * @notice Exchange XDC to xdUSD.
     */
    /* solhint-disable multiple-sends, reentrancy */
    function mintxdUSDForXDC()
        external
        payable
        returns (
            uint256 // Returns the number of Synths (sUSD) Minted
        )
    {
        require(
            msg.value >= minimumXDCDepositAmount,
            "XDC amount Should be minimumXDCDepositAmount limit"
        );
        // How much is the XDC they sent us worth in XDUSD (ignoring the transfer fee)?
        // The multiplication works here because  ExchangeRate().retrieve(XDC_PRICE_FROM_PLUGIN) is specified in
        // 18 decimal places, just like our currency base.
        bytes32 requestId = ExchangeRate().requestData("XDC", "USDT");
        uint256 xdUSDToMint = msg.value.multiplyDecimal(
            ExchangeRate().showPrice(requestId)
        );

        //Apply Cratio
        uint256 _afterCollateralRatioApplied = xdUSDToMint.div(minCRatio);

        totalXDUSDMinted[msg.sender] = totalXDUSDMinted[msg.sender].add(
            _afterCollateralRatioApplied
        );

        return _exchangeXdcForXDUSD(_afterCollateralRatioApplied);
    }

    function _exchangeXdcForXDUSD(uint256 _xdUSDToMintforXDC)
        internal
        returns (uint256)
    {
        require(
            msg.value >= minimumXDCDepositAmount,
            "XDC amount Should be minimumXDCDepositAmount limit"
        );

        //Deposit Entry
        DepositEntry memory deposit = deposits[msg.sender];
        uint256 newAmount = deposit.xdcDeposit.add(msg.value);
        uint256 _xdusdAmount = deposit.xdUsdminted.add(_xdUSDToMintforXDC);

        // add a row in deposit entry and sum up the total value deposited so far
        deposits[msg.sender] = DepositEntry(
            deposit.user,
            newAmount,
            deposit.pliDeposit,
            _xdusdAmount,
            TokenType(0)
        );

        ///updating XDUSD debit
        DebtPool memory xdUSDDebtTotal = debtTotalPool[msg.sender]["XDUSD"];
        uint256 _xdusdSynthValue = xdUSDDebtTotal.synthValue.add(_xdusdAmount);

        debtTotalPool[msg.sender]["XDUSD"] = DebtPool(
            payable(msg.sender),
            "XDUSD",
            _xdusdSynthValue,
            false
        );

        //mint XDUSD for the amount of XDC they staked
        XDUSDCore().mint(msg.sender, _xdUSDToMintforXDC);
        return _xdUSDToMintforXDC;
    }

    /**
     * @notice Exchange XDC to xdUSD.
     */
    /* solhint-disable multiple-sends, reentrancy */
    function mintxdUSDForPLI(uint256 _pliVal, address _tokenAddress)
        external
        returns (
            uint256 // Returns the number of Synths (sUSD) Minted
        )
    {
        require(
            _pliVal >= minimumPLIDepositAmount,
            "PLI amount Should be minimumPLIDepositAmount limit"
        );
        // How much is the XDC they sent us worth in XDUSD (ignoring the transfer fee)?
        // The multiplication works here because  ExchangeRate().retrieve(XDC_PRICE_FROM_PLUGIN) is specified in
        // 18 decimal places, just like our currency base.
        bytes32 requestId = ExchangeRate().requestData("PLI", "USDT");
        uint256 xdUSDToMint = _pliVal.multiplyDecimal(
            ExchangeRate().showPrice(requestId)
        );

        uint256 _afterCollateralRatioApplied = xdUSDToMint.div(minCRatio);

        //Total XDUSD Minted by User
        totalXDUSDMinted[msg.sender] = totalXDUSDMinted[msg.sender].add(
            _afterCollateralRatioApplied
        );

        XRC20Balance(msg.sender, _tokenAddress, _pliVal);
        XRC20Allowance(msg.sender, _tokenAddress, _pliVal);
        transferFundsToContract(_pliVal, _tokenAddress);
        return _exchangePliForXDUSD(_afterCollateralRatioApplied, _pliVal);
    }

    function _exchangePliForXDUSD(uint256 _xdUSDToMintforPli, uint256 _pli)
        internal
        returns (uint256)
    {
        require(
            _pli >= minimumPLIDepositAmount,
            "PLI amount Should be minimumPLIDepositAmount limit"
        );

        DepositEntry memory deposit = deposits[msg.sender];
        uint256 newAmount = deposit.pliDeposit.add(_pli);
        uint256 _xdusdAmount = deposit.xdUsdminted.add(_xdUSDToMintforPli);

        // add a row in deposit entry and sum up the total value deposited so far
        deposits[msg.sender] = DepositEntry(
            deposit.user,
            deposit.xdcDeposit,
            newAmount,
            _xdusdAmount,
            TokenType(1)
        );

        ///updating XDUSD debit
        DebtPool memory xdUSDDebtTotal = debtTotalPool[msg.sender]["XDUSD"];
        uint256 _xdusdSynthValue = xdUSDDebtTotal.synthValue.add(_xdusdAmount);

        debtTotalPool[msg.sender]["XDUSD"] = DebtPool(
            payable(msg.sender),
            "XDUSD",
            _xdusdSynthValue,
            false
        );

        //mint XDUSD for the amount of XDC they staked
        XDUSDCore().mint(msg.sender, _xdUSDToMintforPli);
        return _xdUSDToMintforPli;
    }

    function XDUSDCore() internal view returns (IXDUSDCore) {
        return IXDUSDCore(requireAndGetAddress(CONTRACT_XDUSDCORE));
    }

    function ExchangeRate() internal view returns (IExchangeRate) {
        return IExchangeRate(requireAndGetAddress(CONTRACT_EXCHANGERATE));
    }

    function XsynExchanger() internal view returns (address) {
        return address(requireAndGetAddress(CONTRACT_XSYNEXCHANGE));
    }

    function XRC20Balance(
        address _addrToCheck,
        address _currency,
        uint256 _AmountToCheckAgainst
    ) internal view {
        require(
            IERC20(_currency).balanceOf(_addrToCheck) >= _AmountToCheckAgainst,
            "XRC20Gateway: insufficient currency balance"
        );
    }

    function XRC20Allowance(
        address _addrToCheck,
        address _currency,
        uint256 _AmountToCheckAgainst
    ) internal view {
        require(
            IERC20(_currency).allowance(_addrToCheck, address(this)) >=
                _AmountToCheckAgainst,
            "XRC20Gateway: insufficient allowance."
        );
    }

    function updateDebtPool(
        address _user,
        uint256 _totUsdSwapped,
        uint256 _totSynthsPurchased,
        string memory _symbolPurchased
    ) external onlyExchanger {
        //updating Other synthetix debit
        DebtPool memory debtTotal = debtTotalPool[_user][_symbolPurchased];
        uint256 _synthValue = debtTotal.synthValue.add(_totSynthsPurchased);

        debtTotalPool[_user][_symbolPurchased] = DebtPool(
            payable(_user),
            _symbolPurchased,
            _synthValue,
            false
        );

        ///updating XDUSD debit
        DebtPool memory xdUSDDebtTotal = debtTotalPool[_user]["XDUSD"];
        uint256 _xdusdSynthValue = xdUSDDebtTotal.synthValue.sub(
            _totUsdSwapped
        );

        debtTotalPool[_user]["XDUSD"] = DebtPool(
            payable(_user),
            "XDUSD",
            _xdusdSynthValue,
            false
        );
    }

    //internal function for transferpayment
    function transferFundsToContract(uint256 _amount, address _tokenaddress)
        internal
    {
        IERC20(_tokenaddress).transferFrom(msg.sender, address(this), _amount);
    }

    /* ========== EVENTS ========== */
    event MinimumDepositAmountUpdated(uint256 amount);
}
