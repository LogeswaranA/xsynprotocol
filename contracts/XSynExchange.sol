// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IExchangeRate.sol";
import "./interfaces/IXsynExec.sol";
import "./interfaces/IXsynProtocol.sol";
import "./interfaces/IXDUSDCore.sol";
import "./AddressResolver.sol";
import "./utils/Constants.sol";
import "./utils/SafeDecimalMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract XSynExchange is Constants, AddressResolver {
    using SafeMath for uint256;
    using SafeDecimalMath for uint256;

    string public constant CONTRACTNAME = "XSynExchange";
    bytes32 internal constant CONTRACT_XSYNPROTOCOL = "XSynProtocol";
    bytes32 internal constant CONTRACT_XDBTC = "XDBTC";
    bytes32 internal constant CONTRACT_XDETH = "XDETH";
    bytes32 internal constant CONTRACT_XDPAX = "XDPAX";
    bytes32 internal constant CONTRACT_XDUSD = "XDUSD";
    bytes32 internal constant CONTRACT_EXCHANGERATE = "EXCHANGERATE";

    mapping(address => uint256) public mintr;
    address public contractOwner;

    uint256 public minimumXDUSDDepositAmount = 50 * SafeDecimalMath.unit();

    /* Stores Exhanges from users. */
    struct ExchangeEntry {
        // The user that made the exchange
        address payable user;
        uint256 xdUsdDeposit;
        uint256 synthsExchanged;
        address currencyAddress;
        uint256 exchangedOn;
    }

    mapping(address => mapping(bytes32 => ExchangeEntry)) public exchanges;

    constructor() {
        contractOwner = msg.sender;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAuthorized() {
        require(
            msg.sender == contractOwner,
            "XSynExchange: Only Authorized Wallet can perfor this operation"
        );
        _;
    }

    /**
     * @notice Fallback function
     */
    receive() external payable {}

    function setMinDepositForXDUSD(uint256 _minDeposit)
        external
        onlyAuthorized
    {
        minimumXDUSDDepositAmount = _minDeposit;
        emit MinimumDepositAmountUpdated(minimumXDUSDDepositAmount);
    }

    /**
     * @notice Exchange XDC to xdUSD.
     */
    /* solhint-disable multiple-sends, reentrancy */
    function exchangeXDUSDForSynths(
        uint256 _amount,
        address _preferredSynthAddress,
        bytes32  _preferredSynthSymbol,
        string memory _woprefixSynth,
        string memory _wprefixSynth
    ) external returns (uint256) {
        require(
            _amount >= minimumXDUSDDepositAmount,
            "XDUSD amount Should be minimumXDUSDDepositAmount limit"
        );
        require(
            isRequireAndGetAddress(_preferredSynthSymbol),
            "Symbol not supported"
        );
        XRC20Balance(msg.sender, requireAndGetAddress(CONTRACT_XDUSD), _amount);
        XRC20Allowance(
            msg.sender,
            requireAndGetAddress(CONTRACT_XDUSD),
            _amount
        );

        uint256 synthsToMint = _amount.multiplyDecimal(
            ExchangeRate().showCurrentPrice(_woprefixSynth).div(10000)
        );
        transferFundsToContract(_amount, requireAndGetAddress(CONTRACT_XDUSD));
        return
            _exchangeXDUSDForSynths(
                synthsToMint,
                _amount,
                _preferredSynthSymbol,
                _preferredSynthAddress,
                _wprefixSynth
            );
    }

    function _exchangeXDUSDForSynths(
        uint256 _synthsToMint,
        uint256 __xdusdAmt,
        bytes32  __preferredSynthSymbol,
        address __preferredSynthAddress,
        string memory _wprefixSynth
    ) internal returns (uint256) {
        ExchangeEntry memory exchange = exchanges[msg.sender][
            __preferredSynthSymbol
        ];
        uint256 _xdUsdNewBalance = exchange.xdUsdDeposit.add(__xdusdAmt);
        uint256 _synthsNewBalance = exchange.synthsExchanged.add(_synthsToMint);

        // add a row in deposit entry and sum up the total value deposited so far
        exchanges[msg.sender][__preferredSynthSymbol] = ExchangeEntry(
            payable(msg.sender),
            _xdUsdNewBalance,
            _synthsNewBalance,
            __preferredSynthAddress,
            block.timestamp
        );
        //mint respective Synthetix for the amount of XDC they staked
        XsynExec(__preferredSynthSymbol).mint(msg.sender, _synthsToMint);
        XSynProtocol().updateDebtPool(
            msg.sender,
            __xdusdAmt,
            _synthsToMint,
            _wprefixSynth
        );
        return _synthsToMint;
    }

    function XsynExec(bytes32 _Symbol) internal view returns (IXsynExec) {
        return IXsynExec(requireAndGetAddress(_Symbol));
    }

    function ExchangeRate() internal view returns (IExchangeRate) {
        return IExchangeRate(requireAndGetAddress(CONTRACT_EXCHANGERATE));
    }

    function XDUSDCore() internal view returns (IXDUSDCore) {
        return IXDUSDCore(requireAndGetAddress(CONTRACT_XDUSD));
    }

    function XSynProtocol() internal view returns (IXsynProtocol) {
        return IXsynProtocol(requireAndGetAddress(CONTRACT_XSYNPROTOCOL));
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

    //internal function for transferpayment
    function transferFundsToContract(uint256 _amount, address _tokenaddress)
        internal
    {
        IERC20(_tokenaddress).transferFrom(msg.sender, address(this), _amount);
    }

    /* ========== EVENTS ========== */
    event MinimumDepositAmountUpdated(uint256 amount);
}
