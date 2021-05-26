// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.4.22 <0.9.0;
import "openzeppelin-solidity/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "./Recoverable.sol";
import "./Libraries/NTransferUtilV1.sol";

abstract contract Admin is Recoverable, ReentrancyGuard {
  using SafeMath for uint256;

  IERC20 public immutable _nepToken;
  uint256 public _bountyReleaseDate;
  uint256 public immutable _bountyAmount;
  uint256 public immutable _totalBountyAmount;

  uint256 public _startDate;
  uint256 public _endDate;

  struct Entry {
    address account;
    uint256 time;
    uint256 amount;
    uint256 value;
    string reason;
  }

  Entry[] public _failedEntries;
  Entry[] public _entries;

  mapping(address => uint256) _entryCount;
  mapping(address => uint256) _failedEntryCount;
  mapping(address => bool) _winners;
  mapping(address => bool) _claimed;

  uint256 public constant MAX_WINNERS = 250;
  uint256 public _totalWinners;
  bool public _refilled;

  event Registered(address indexed account);
  event Refunded(address indexed account, uint256 value, string reason);
  event BountyReleaseDateSet(uint256 date);
  event BountyClaimed(address indexed account, uint256 amount);
  event Refilled(address indexed refilledBy, uint256 amount);
  event DateSet(uint256 startDate, uint256 endDate);

  constructor(IERC20 nepToken, uint256 bountyAmount) {
    _nepToken = nepToken;
    _bountyAmount = bountyAmount;
    _totalBountyAmount = bountyAmount * MAX_WINNERS;
  }

  /**
   * @dev Setting the dates starts the
   */
  function setDates(uint256 startDate, uint256 endDate) external onlyOwner {
    require(startDate > 0, "Provide start date");
    require(endDate > startDate, "Provide a valid end date");

    require(_startDate == 0, "Already set");

    _startDate = startDate;
    _endDate = endDate;

    emit DateSet(startDate, endDate);
  }

  /**
   * @dev The admin needs to recharge this smart contract with NEP tokens once.
   */
  function refill() external onlyOwner {
    require(_refilled == false, "Already refilled");
    _refilled = true;

    _nepToken.transferFrom(msg.sender, address(this), _totalBountyAmount);
    emit Refilled(msg.sender, _totalBountyAmount);
  }

  /**
   * @dev Updates the winner list
   */
  function updateWinners(address[] memory accounts) external onlyOwner {
    require(block.timestamp > _endDate, "The campaign is still ongoing");

    uint256 count = 0;

    for (uint256 i = 0; i < accounts.length; i++) {
      if (!_winners[accounts[i]]) {
        count++;
        _winners[accounts[i]] = true;
      }
    }

    _totalWinners.add(count);
    require(_totalWinners <= MAX_WINNERS, "This exceeds maximum winner count");

    // 6 month bounty token locked
    if (_bountyReleaseDate == 0) {
      _bountyReleaseDate = block.timestamp.add(180 days);
      emit BountyReleaseDateSet(_bountyReleaseDate);
    }
  }
}
