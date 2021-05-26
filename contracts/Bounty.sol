// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.4.22 <0.9.0;
import "./Admin.sol";

contract Bounty is Admin {
  using SafeMath for uint256;
  using NTransferUtilV1 for IERC20;

  constructor(IERC20 nepToken, uint256 bountyAmount)
    Admin(nepToken, bountyAmount)
  {}

  /**
   * @dev A winner can claim reward after the bounty release date.
   */
  function claim() external nonReentrant {
    require(_winners[msg.sender], "Sorry, you can't claim");
    require(_claimed[msg.sender] == false, "You have already claimed");
    require(block.timestamp > _bountyReleaseDate, "You're early");

    _claimed[msg.sender] = true;
    _nepToken.safeTransfer(msg.sender, _bountyAmount);
  }

  /**
   * @dev You can verify whether your registration was successful.
   */
  function checkRegistration(address account) external view returns (bool) {
    return _entryCount[account] > 0;
  }

  /**
   * @dev Check when you can withdraw your rewards and how much
   */
  function checkReward(address account)
    external
    view
    returns (uint256 amount, uint256 releaseDate)
  {
    bool claimed = _claimed[msg.sender];

    if (_winners[account] && !claimed) {
      amount = _bountyAmount;
      releaseDate = _bountyReleaseDate;
    }
  }

  /**
   * @dev Accepts zero-valued transactions only if
   *
   * 1. The campaign is active (during start and finish dates)
   * 3. The NEP balance of this contract is greater than zero
   *
   * Fully refunds all BNBs received.
   */
  receive() external payable nonReentrant {
    if (block.timestamp < _startDate) {
      // solhint-disable-previous-line
      return _refund("This campaign has not begun");
    }

    if (block.timestamp > _endDate) {
      // solhint-disable-previous-line
      return _refund("This campaign already ended");
    }

    if (_nepToken.balanceOf(address(this)) == 0) {
      return _refund("The campaign is not open");
    }

    if (msg.value > 0) {
      return
        _refund("Your BNB is refunded. Try again with zero-value transfer.");
    }

    _register();
  }

  /**
   * Registers and adds the sender to the entry list
   */
  function _register() private {
    Entry memory entry;

    entry.account = msg.sender;
    entry.time = block.timestamp; // solhint-disable-line
    entry.value = msg.value;
    entry.reason = "Registration";

    _entries.push(entry);
    _entryCount[msg.sender] = _entryCount[msg.sender].add(1);
    _winners[msg.sender] = false;

    address payable you = payable(msg.sender);
    you.transfer(msg.value);

    emit Registered(msg.sender);
  }

  /**
   * @dev Returns the received BNB back to the sender
   */
  function _refund(string memory reason) private {
    Entry memory fail;

    fail.account = msg.sender;
    fail.time = block.timestamp; // solhint-disable-line
    fail.value = msg.value;
    fail.reason = reason;

    _failedEntries.push(fail);
    _failedEntryCount[msg.sender] = _failedEntryCount[msg.sender].add(1);

    address payable you = payable(msg.sender);
    you.transfer(msg.value);

    emit Refunded(msg.sender, msg.value, reason);
  }
}
